const std = @import("std");
const builtin = @import("builtin");

const log = std.log;
const fs = std.fs;
const mem = std.mem;
const assert = std.debug.assert;
const time = std.time;
const rand = std.rand;
const os = std.os;
const posix = std.posix;

pub const log_level: log.Level = .info;

const config = @import("config.zig").playvideos_config;

pub fn setsid() !posix.pid_t {
    // with the help of Lee Cannon on discord
    const rc = os.linux.syscall0(.setsid);
    switch (posix.errno(rc)) {
        .SUCCESS => return @intCast(rc),
        .PERM => return error.AlreadyProcessGroupLeader,
        else => |errno| return posix.unexpectedErrno(errno),
    }
}

const TOC = struct {
    arena_alloc: std.heap.ArenaAllocator,
    items: []const []const u8,

    const Self = @This();

    fn deinit(self: Self) void {
        self.arena_alloc.deinit();
    }

    /// deinit should be called eventually.
    fn init(base_allocator: mem.Allocator, roots: []const []const u8, random: ?rand.Random) !TOC {
        var arena_alloc = std.heap.ArenaAllocator.init(base_allocator);
        errdefer arena_alloc.deinit();

        const allocator = arena_alloc.allocator();

        var list = std.ArrayList([]const u8).init(allocator);

        for (roots) |root| {
            var dir = fs.openDirAbsolute(root, .{ .iterate = true }) catch |err| switch (err) {
                error.FileNotFound, error.AccessDenied => {
                    log.info("skipped {s}; err={}", .{ root, err });
                    continue;
                },
                else => {
                    log.err("unexpected err on opening {s}; err={}", .{ root, err });
                    return err;
                },
            };
            defer dir.close();

            var it = try dir.walk(base_allocator);
            defer it.deinit();

            while (try it.next()) |entry| {
                if (entry.kind != fs.File.Kind.file) continue;
                const is_video = video: {
                    for (config.suffixes) |suffix| {
                        if (mem.endsWith(u8, entry.basename, suffix)) {
                            break :video true;
                        }
                    }
                    break :video false;
                };
                if (!is_video) continue;

                const path = try fs.path.join(allocator, &.{ root, entry.path });
                try list.append(path);
            }
        }

        const items = try list.toOwnedSlice();
        if (random) |r| {
            r.shuffle([]const u8, items);
            // i'd like to shuffle it again
            r.shuffle([]const u8, items);
        }

        return TOC{
            .arena_alloc = arena_alloc,
            .items = items,
        };
    }
};

const Player = struct {
    allocator: mem.Allocator,
    parallel: u8,
    toc: TOC,
    pids: Pids,
    cursor: usize,

    const Pids = std.TailQueue(posix.pid_t);
    const Self = @This();

    fn spawn(allocator: mem.Allocator, argv: []const []const u8) !posix.pid_t {
        // stole from std.ChildProcess.spawnPosix
        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const argv_buf = try arena.allocSentinel(?[*:0]u8, argv.len, null);
        for (argv, 0..) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

        const envp: [*:null]?[*:0]u8 = if (builtin.output_mode == .Exe)
            @ptrCast(os.environ.ptr)
        else
            unreachable;

        const pid = try posix.fork();

        if (pid == 0) {
            posix.close(0);
            posix.close(1);
            posix.close(2);
            _ = try setsid();
            const err = posix.execvpeZ_expandArg0(.no_expand, argv_buf.ptr[0].?, argv_buf.ptr, envp);
            log.err("failed to exec: {}", .{err});
            unreachable;
        }

        return pid;
    }

    /// Player.deinit() should be called eventually.
    fn init(allocator: mem.Allocator, parallel: u8, toc: TOC) Self {
        return .{
            .parallel = parallel,
            .allocator = allocator,
            .toc = toc,
            .pids = .{},
            .cursor = 0,
        };
    }

    fn deinit(self: *Self) void {
        var next = self.pids.first;
        while (next) |node| {
            next = node.next;
            const pid = node.data;
            posix.kill(pid, posix.SIG.HUP) catch |err| {
                log.err("failed to kill mpv; pid={d}, err={}\n", .{ pid, err });
            };
            self.pids.remove(node);
            self.allocator.destroy(node);
        }
    }

    fn play(self: *Self) !void {
        // play all the videos, self.parallel at a time
        const interval = time.ns_per_ms * 250;
        while (true) {
            if (self.cursor >= self.toc.items.len) break;

            if (!self.haveRoom()) {
                time.sleep(interval);
                continue;
            }

            defer self.cursor += 1;

            const file = self.toc.items[self.cursor];
            log.info("playing {s}", .{file});
            const pid = try spawn(self.allocator, &.{ "/usr/bin/mpv", "--x11-name=mpv-grid", "--mute=yes", "--no-terminal", file });
            const node = try self.allocator.create(Pids.Node);
            node.data = pid;
            self.pids.prepend(node);
        }
    }

    fn makeOneRoom(self: *Self) void {
        const dead = posix.waitpid(-1, posix.W.NOHANG);
        var next = self.pids.first;
        var found: u8 = 0;
        while (next) |node| {
            next = node.next;
            if (dead.pid == node.data) {
                self.pids.remove(node);
                self.allocator.destroy(node);
                found += 1;
            }
        }
        assert(found == 1);
    }

    fn haveRoom(self: *Self) bool {
        return self.pids.len < self.parallel;
    }

    fn handleSIGCHLD(self: *Self) void {
        self.makeOneRoom();
    }

    fn handleEXIT(self: *Self) void {
        log.info("player exiting", .{});
        self.cursor = self.toc.items.len;
    }
};

var PLAYER: ?*Player = null;

fn handleSIGCHLD(_: c_int) callconv(.C) void {
    if (PLAYER) |player| {
        player.handleSIGCHLD();
    }
}

const act_chld: posix.Sigaction = .{
    .handler = .{ .handler = handleSIGCHLD },
    .mask = posix.empty_sigset,
    .flags = 0,
};

fn handleEXIT(_: c_int) callconv(.C) void {
    if (PLAYER) |player| {
        player.handleEXIT();
    }
}

const act_exit: posix.Sigaction = .{
    .handler = .{ .handler = handleEXIT },
    .mask = posix.empty_sigset,
    .flags = 0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() != .leak);

    const allocator = gpa.allocator();

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    var roots_need_free = false;
    const roots = blk: {
        var arg_iter = std.process.ArgIteratorPosix.init();
        roots_need_free = arg_iter.count > 1;
        if (!roots_need_free) break :blk config.roots;

        var arg_roots = std.ArrayList([]const u8).init(allocator);
        errdefer arg_roots.deinit();

        assert(arg_iter.skip());
        while (arg_iter.next()) |arg| {
            const path = try std.fs.path.resolve(allocator, &.{arg});
            errdefer allocator.free(path);
            try arg_roots.append(path);
        }

        break :blk try arg_roots.toOwnedSlice();
    };
    defer if (roots_need_free) {
        for (roots) |root| allocator.free(root);
        allocator.free(roots);
    };
    log.info("roots: {s}", .{roots});

    const toc = try TOC.init(allocator, roots, prng.random());
    defer toc.deinit();

    log.info("the length of toc: {}", .{toc.items.len});

    var player = Player.init(allocator, config.player_num, toc);
    defer player.deinit();

    PLAYER = &player;
    defer PLAYER = null;

    try posix.sigaction(posix.SIG.CHLD, &act_chld, null);
    try posix.sigaction(posix.SIG.INT, &act_exit, null);
    try posix.sigaction(posix.SIG.TERM, &act_exit, null);

    try player.play();

    // empty the pids list to prevent player.deinit killing them.
    var next = player.pids.first;
    while (next) |node| {
        next = node.next;
        player.pids.remove(node);
        player.allocator.destroy(node);
    }
}

// millet: zig build-exe -O ReleaseFast -fsingle-threaded

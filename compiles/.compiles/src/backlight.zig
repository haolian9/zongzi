/// https://www.kernel.org/doc/Documentation/ABI/stable/sysfs-class-backlight
/// * brightness
/// * actual_brightness
/// * max_brightness
/// * type
const std = @import("std");
const assert = std.debug.assert;
const log = std.log;
const testing = std.testing;

const Error = error{
    NoDeviceFound,
    TooMuchDevices,
};

const Device = struct {
    fs: std.fs.Dir,

    const Self = @This();

    const Info = struct {
        brightness: i64,
        max_brightness: i64,
    };

    //  self.deinit() must be honored
    fn init(root_path: []const u8) !Device {
        const dir = try std.fs.openDirAbsolute(root_path, .{ .iterate = true });
        return Device{ .fs = dir };
    }

    fn deinit(self: *Self) void {
        self.fs.close();
    }

    fn info(self: Self) !Info {
        return Info{
            .brightness = try self.getInt(i64, "brightness"),
            .max_brightness = try self.getInt(i64, "max_brightness"),
        };
    }

    fn setBrightness(self: Self, brightness: i64) !void {
        var file = try self.fs.openFile("brightness", .{ .mode = .write_only });
        defer file.close();

        // todo: handles .INVAL
        try std.fmt.format(file.writer(), "{d}", .{brightness});
    }

    fn getInt(self: Self, comptime T: type, path: []const u8) !T {
        var file = try self.fs.openFile(path, .{});
        defer file.close();

        const buf_len = comptime blk: {
            var remain = std.math.maxInt(T);
            var len = 0;
            while (remain > 10) {
                remain = remain / 10;
                len += 1;
            }
            // one for `\n`
            break :blk len + 1;
        };
        var buf: [buf_len]u8 = undefined;
        const n = try file.readAll(&buf);
        assert(buf[n - 1] == '\n');
        const raw = buf[0 .. n - 1];

        return try std.fmt.parseInt(T, raw, 10);
    }
};

fn resolveBrightness(held: Device.Info, desc: []const u8) !i64 {
    const change = try std.fmt.parseInt(i64, desc, 10);
    return switch (desc[0]) {
        // signed
        '+' => @min(held.brightness + change, held.max_brightness),
        '-' => @max(held.brightness + change, 0),
        // set to
        else => @min(change, held.max_brightness),
    };
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = blk: {
        const root_path = "/sys/class/backlight";
        var root_dir = try std.fs.openDirAbsolute(root_path, .{ .access_sub_paths = false, .iterate = true });
        defer root_dir.close();

        var iter = root_dir.iterate();
        const basename = if (try iter.next()) |entry| entry.name else return Error.NoDeviceFound;
        if ((try iter.next()) != null) return Error.TooMuchDevices;

        break :blk try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ root_path, basename });
    };

    var dev = try Device.init(path);
    defer dev.deinit();

    const info = try dev.info();

    const value = blk: {
        var arg_iter = std.process.ArgIterator.init();
        defer arg_iter.deinit();

        assert(arg_iter.skip());
        const arg1 = arg_iter.next();

        // show info
        if (arg1 == null) return try stdout.print("brightness: {d}/{d}\n", .{ info.brightness, info.max_brightness });

        break :blk try resolveBrightness(info, arg1.?);
    };

    if (value == info.brightness) return;

    log.info("setting brightness to {}", .{value});
    try dev.setBrightness(value);
}

test "resolveBrightness" {
    const info = Device.Info{ .brightness = 900, .max_brightness = 930 };
    try testing.expectEqual(try resolveBrightness(info, "+300"), info.max_brightness);
    try testing.expectEqual(try resolveBrightness(info, "-901"), 0);
    try testing.expectEqual(try resolveBrightness(info, "300"), 300);
    try testing.expectEqual(try resolveBrightness(info, "1000"), 930);
}

// millet: zig run %:p -- +300
// millet: zig test

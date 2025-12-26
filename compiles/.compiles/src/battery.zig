/// /sys/class/power_supply/{ADB,BAT}{n}
/// * capacity
/// * capacity_level
/// * energy_full_design
/// * energy_full
/// * energy_now
/// * status: discharging, charging
/// * type: Battery, Mains
const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var root = try fs.openDirAbsolute("/sys/class/power_supply/BAT1", .{ .iterate = true });
    defer root.close();

    {
        const pert: f64 = blk: {
            var buf: [64]u8 = undefined;
            const energy_full = blk2: {
                const raw = try root.readFile("energy_full", &buf);
                break :blk2 try fmt.parseInt(u64, mem.trimRight(u8, raw, "\n"), 10);
            };
            const energy_now = blk2: {
                const raw = try root.readFile("energy_now", &buf);
                break :blk2 try fmt.parseInt(u64, mem.trimRight(u8, raw, "\n"), 10);
            };
            break :blk (@as(f64, @floatFromInt(energy_now)) / @as(f64, @floatFromInt(energy_full))) * 100;
        };
        var stbuf: [16]u8 = undefined;
        const status = blk: {
            const raw = try root.readFile("status", &stbuf);
            break :blk mem.trimRight(u8, raw, "\n");
        };
        // todo: (energy_full/energy_full_design) * 100
        try stdout.print("{d:.2}% {s}\n", .{ pert, status });
    }
}

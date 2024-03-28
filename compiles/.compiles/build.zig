const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{});
    // const output_dir = b.pathJoin(&.{ b.env_map.get("HOME").?, "bin" });

    const install = b.getInstallStep();

    inline for (.{ "playvideos", "backlight", "battery" }) |name| {
        const bin = b.addExecutable(.{
            .name = name,
            .root_source_file = .{ .path = "src/" ++ name ++ ".zig" },
            .optimize = optimize,
            .single_threaded = true,
        });
        const a = b.addInstallArtifact(bin, .{
            // .dest_dir = .{ .override = .{ .custom = output_dir } },
        });
        install.dependOn(&a.step);
    }

    {
        const bin = b.addExecutable(.{
            .name = "rimeascii",
            .root_source_file = .{ .path = "src/rimeascii.zig" },
            .optimize = optimize,
            .single_threaded = true,
            .link_libc = true,
        });
        bin.linkSystemLibrary("dbus-1");

        const a = b.addInstallArtifact(bin, .{
            // .dest_dir = .{ .override = .{ .custom = output_dir } },
        });

        install.dependOn(&a.step);
    }

    {
        const t = b.addTest(.{
            .root_source_file = .{ .path = "src/test.zig" },
            .optimize = optimize,
            .link_libc = true,
        });
        t.linkSystemLibrary("dbus-1");

        const a = b.addRunArtifact(t);
        const step = b.step("test", "run tests");
        step.dependOn(&a.step);
    }
}

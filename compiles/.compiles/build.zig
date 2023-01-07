const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const strip = mode != .Debug;
    const output_dir = b.pathJoin(&.{ b.env_map.get("HOME").?, "bin" });

    {
        const exe = b.addExecutable("playvideos", "playvideos.zig");
        exe.setBuildMode(mode);
        exe.setOutputDir(output_dir);
        exe.single_threaded = true;
        exe.strip = strip;
        exe.install();
    }

    {
        const exe = b.addExecutable("rimeascii", "rimeascii.zig");
        exe.setBuildMode(mode);
        exe.setOutputDir(output_dir);
        exe.strip = strip;
        exe.linkLibC();
        exe.linkSystemLibrary("dbus-1");
        exe.install();
    }
}

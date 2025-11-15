const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const so = b.addSharedLibrary(.{
        .name = "capsbulb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    so.linkLibC();
    so.linkSystemLibrary("X11");
    b.installArtifact(so);

    const exe = b.addExecutable(.{
        .name = "capsbulb",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("X11");
    b.installArtifact(exe);
}

const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

// TODO: automate this when official zig pm releases

/// Provides the YOZZ modules
pub const yozz = Pkg {
    .name = "yozz",
    .source = FileSource { .path = "__yozz__/yozz/yozz.zig", },
};

// 

const yozz_app = @import("__yozz__/yozz/app.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("project", "src/main.zig");

    yozz_app.prepare(exe);

    exe.addPackage(yozz);

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("html_purser_wasm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Native executable
    const exe = b.addExecutable(.{
        .name = "html_purser_wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "html_purser_wasm", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    // Streaming demo executable
    const streaming_exe = b.addExecutable(.{
        .name = "streaming_demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/streaming_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(streaming_exe);

    const streaming_step = b.step("demo-streaming", "Run streaming parser demo");
    const streaming_cmd = b.addRunArtifact(streaming_exe);
    streaming_step.dependOn(&streaming_cmd.step);
    streaming_cmd.step.dependOn(b.getInstallStep());

    // WASM library
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const wasm = b.addExecutable(.{
        .name = "html_purser_wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;
    
    const wasm_install = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "wasm" } },
    });

    const wasm_step = b.step("wasm", "Build WASM library");
    wasm_step.dependOn(&wasm_install.step);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

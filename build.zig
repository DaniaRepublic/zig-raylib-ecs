const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ray_mod = b.addModule("ray", .{
        .root_source_file = b.path("src/ray.zig"),
        .optimize = optimize,
        .target = target,
    });

    const ecs = b.dependency("entt", .{
        .target = target,
        .optimize = optimize,
    });
    const ecs_mod = ecs.module("zig-ecs");

    const exe_gui = b.addExecutable(.{
        .name = "gui",
        .root_source_file = b.path("src/gui.zig"),
        .optimize = optimize,
        .target = target,
    });

    const exe_main = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // add raylib and raygui to the same module.
    {
        const raylib_dep = b.dependency("raylib", .{
            .target = target,
            .optimize = optimize,
        });
        const raylib_artifact = raylib_dep.artifact("raylib");

        ray_mod.linkLibrary(raylib_artifact);

        ray_mod.addCSourceFile(.{ .file = .{ .cwd_relative = "c-libs/raygui.c" } });
        ray_mod.addIncludePath(.{ .cwd_relative = "c-libs/" });
    }

    exe_gui.root_module.addImport("ray", ray_mod);

    exe_main.root_module.addImport("ray", ray_mod);
    exe_main.root_module.addImport("gui", exe_gui.root_module);
    exe_main.root_module.addImport("ecs", ecs_mod);

    b.installArtifact(exe_main);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe_main);
    run_cmd.step.dependOn(&exe_main.step);
    run_step.dependOn(&run_cmd.step);

    // examples
    {
        var exe_example = b.addExecutable(.{
            .name = "example",
            .target = target,
            .optimize = optimize,
        });

        if (b.option([]const u8, "example", "= float-window | comptime-types")) |example_name| {
            if (std.mem.eql(u8, example_name, "float-window")) {
                exe_example.root_module.root_source_file = b.path("src/examples/float-window.zig");
                exe_example.root_module.addImport("ray", ray_mod);
                exe_example.root_module.addImport("gui", exe_gui.root_module);
            } else if (std.mem.eql(u8, example_name, "comptime-types")) {
                exe_example.root_module.root_source_file = b.path("src/examples/comptime-types.zig");
            } else {
                std.debug.print("Unknown example: {s}\nSee available options in Project-Specific Options section.\nExiting\n", .{example_name});
                std.process.exit(1);
            }
        }

        const run_example = b.step("run-example", "Need to provide -Dexample=<name> option. See its description in Project-Specific Options section.");
        const run_cmd_example = b.addRunArtifact(exe_example);
        run_cmd_example.step.dependOn(&exe_example.step);
        run_example.dependOn(&run_cmd_example.step);
    }
}

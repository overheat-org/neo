const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

	const exe_mod = b.createModule(.{
		.root_source_file = b.path("./src/main.zig"),
		.target = target,
		.optimize = optimize,
	});
	
    const exe = b.addExecutable(.{
		.name = "lua-rt",
		.root_module = exe_mod,
	});

	const neo_mod = b.addModule("neo", .{
		.root_source_file = b.path("../../neo/src/root.zig"),
		.target = target,
		.optimize = optimize,
	});

	exe.root_module.addImport("neo", neo_mod);
	
    const tests = b.addTest(.{
		.root_module = exe_mod,
    });
    tests.root_module.addImport("neo", neo_mod);
	
	const run_tests = b.addRunArtifact(tests);

    b.default_step.dependOn(&exe.step);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

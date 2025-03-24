const std = @import("std");
const NeoError = @import("./reporter.zig");

const allocator = std.heap.page_allocator;

pub fn unwrap_error(arg: anytype) @typeInfo(@TypeOf(arg)).error_union.payload {
	return arg catch |err| switch (err) {
		std.mem.Allocator.Error.OutOfMemory => NeoError.throw(.{
			.err = .OutOfMemory
		})
	};
}

pub fn format(comptime fmt: []const u8, args: anytype) []u8 {
	return std.fmt.allocPrint(allocator, fmt, args) 
		catch NeoError.throw(.{ .err = .OutOfMemory });
}
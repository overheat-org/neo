const std = @import("std");
const Allocator = std.mem.Allocator;
const _runtime = @import("./runtime.zig");
const RuntimeValue = _runtime.RuntimeValue;

const Self = @This();

variables: std.StringHashMap(RuntimeValue),
allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return Self{
        .variables = std.StringHashMap(RuntimeValue).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: Self) void {
    self.variables.deinit();
}

pub fn set(self: *Self, name: []const u8, value: RuntimeValue) Allocator.Error!void {
    std.debug.print("SET: {s}\n", .{name});
    try self.variables.put(name, value);
}

pub fn get(self: *Self, name: []const u8) ?RuntimeValue {
    const a = self.variables.get(name);
    std.debug.print("GET: {any}\n", .{a.?});
    return a;
}

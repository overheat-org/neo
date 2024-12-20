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

pub fn deinit(self: *Self) void {
    var it = self.variables.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);
    }
    self.variables.deinit();
}

pub fn set(self: *Self, name: []const u8, value: RuntimeValue) Allocator.Error!void {
    const dupe_name = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(dupe_name);

    if (self.variables.getKey(name)) |old_key| {
        self.allocator.free(old_key);
    }

    std.debug.print("\n\nDUPED: {s}\nNAME: {s}", .{ dupe_name, name });

    try self.variables.put(dupe_name, value);
}

pub fn get(self: *Self, name: []const u8) ?RuntimeValue {
    const a = self.variables.get(name);
    return a;
}

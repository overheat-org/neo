const std = @import("std");
const Parser = @import("./parser.zig");
const Node = @import("./ast.zig").Node;
const Runtime = @import("./runtime.zig");

pub fn main() !void {
    const value = try Runtime.run("5 * 3");

    std.debug.print("{any}", .{switch (value.type) {
        .Number => value.value.Number,
        else => unreachable,
    }});
}

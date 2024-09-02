const std = @import("std");
const Parser = @import("./parser.zig");
const Node = @import("ast.zig").Node;

pub fn main() !void {
    const AST = try Parser.init("5 + 5");

    // var string = std.ArrayList(u8).init(std.heap.page_allocator);
    // try std.json.stringify(AST, .{}, string.writer());

    std.debug.print("{any}", .{AST});
    // std.debug.print("{s}", .{string.items});
}

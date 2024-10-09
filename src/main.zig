const std = @import("std");
const Parser = @import("./parser.zig");
const Node = @import("./ast.zig").Node;
const Runtime = @import("./runtime.zig");
const REPL = @import("./repl.zig").REPL;

pub fn main() !void {
    try REPL();
    // std.debug.print("{any}", .{switch (runtimeValue.type) {
    //     .Number => runtimeValue.value.Number,
    //     else => unreachable,
    // }});
}

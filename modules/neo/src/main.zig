const std = @import("std");
const REPL = @import("./repl.zig").REPL;

pub fn main() !void {
    try REPL();
}

const std = @import("std");
const Runtime = @import("./runtime.zig");

const allocator = std.heap.page_allocator;

pub fn REPL() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    while (true) {
        _ = try stdout.write("> ");
        const source = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024 * 10);
        defer allocator.free(source);

        const result = try Runtime.run(source);

        _ = try stdout.write(result);
        _ = try stdout.write("\n");
    }
}

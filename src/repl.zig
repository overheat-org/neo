const std = @import("std");
const Parser = @import("./parser.zig");
const Runtime = @import("./runtime.zig");
const Env = @import("./env.zig");

const allocator = std.heap.page_allocator;

pub fn REPL() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var env = Env.init(allocator);
    defer env.deinit();

    while (true) {
        _ = try stdout.write("> ");
        const source = try stdin.readUntilDelimiterAlloc(allocator, '\n', 1024 * 10);
        defer allocator.free(source);

        const parser = Parser.init(allocator);
        defer parser.deinit();

        const runtime = Runtime.init(allocator);

        const ast = try parser.parse(source);
        const rt = try runtime.evaluate(&ast, &env);

        const result = switch (rt.type) {
            .Number => try std.fmt.allocPrint(allocator, "{d}", .{rt.value.Number}),
            .Null => try std.fmt.allocPrint(allocator, "null", .{}),
            .Boolean => try std.fmt.allocPrint(allocator, "{s}", .{if (rt.value.Boolean == 1) "true" else "false"}),
            else => unreachable,
        };
        defer allocator.free(result);

        _ = try stdout.write(result);
        _ = try stdout.write("\n");
    }
}

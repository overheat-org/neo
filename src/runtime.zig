const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;

const allocator = std.heap.page_allocator;

const RuntimeValue = struct {
    type: TokenTag,
    value: union { Number: f64, Null: u0, Boolean: u1 },

    pub fn mkBool(boolean: bool) RuntimeValue {
        return .{
            .type = TokenTag.Boolean,
            .value = .{ .Boolean = if (boolean) 1 else 0 },
        };
    }

    pub fn mkNumber(number: f64) RuntimeValue {
        return .{
            .type = TokenTag.Number,
            .value = .{ .Number = number },
        };
    }

    pub fn mkNull() RuntimeValue {
        return .{
            .type = TokenTag.Null,
            .value = .{ .Null = 0 },
        };
    }
};

// zig fmt: off
fn evaluate(node: *const Node) RuntimeValue {
    return switch (node.kind) {
        .Program => {
            var last_evaluated: ?RuntimeValue = null;

            for (node.children) |statement| {
                last_evaluated = evaluate(statement);
            }

            return last_evaluated orelse RuntimeValue.mkNull();
        },
        .BinaryExpression => {
            const node_props = node.props.?.BinaryExpression;
            const left_value = evaluate(node_props.left).value.Number;
            const right_value = evaluate(node_props.right).value.Number;

            return RuntimeValue.mkNumber(switch (node_props.operator) {
                .Plus => left_value + right_value,
                .Minus => left_value - right_value,
                .Asterisk => left_value * right_value,
                .Slash => left_value / right_value,
                .Percent => @mod(left_value, right_value),
                else => @panic("Invalid operator of binary expression"),
            });
        },
        .ComparationExpression => {
            const node_props = node.props.?.ComparationExpression;
            const left_node = evaluate(node_props.left);
            const right_node = evaluate(node_props.right);

            const comparation_type: TokenTag = (
                if (left_node.type == .Number and right_node.type == .Number) TokenTag.Number
                else @panic("vish")
            );

            return RuntimeValue.mkBool(switch (node_props.operator) {
                .DoubleEqual => switch (comparation_type) {
                    .Number => left_node.value.Number == right_node.value.Number,
                    else => @panic("")
                },
                else => unreachable
            });
        },
        .Number => {
            return RuntimeValue.mkNumber(node.props.?.Number.value);
        },
        else => {
            @panic("?");
        },
    };
}
// zig fmt: on

pub fn run(source: []const u8) Parser.Errors![]u8 {
    const parser = try Parser.init(source);
    defer parser.deinit();

    const rt = evaluate(&parser.result);

    // FIXME: memory leak below
    return switch (rt.type) {
        .Number => try std.fmt.allocPrint(allocator, "{d}", .{rt.value.Number}),
        .Null => try std.fmt.allocPrint(allocator, "null", .{}),
        .Boolean => try std.fmt.allocPrint(allocator, "{s}", .{if (rt.value.Boolean == 1) "true" else "false"}),
        else => unreachable,
    };
}

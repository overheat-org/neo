const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;

const allocator = std.heap.page_allocator;

const RuntimeValue = struct {
    type: TokenTag,
    value: union {
        Number: f64,
        Null: u0,
    },

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

fn eval_binary_expr(left: RuntimeValue, right: RuntimeValue, operator: TokenTag) RuntimeValue {
    const left_value = left.value.Number;
    const right_value = right.value.Number;

    return RuntimeValue.mkNumber(switch (operator) {
        .Plus => left_value + right_value,
        .Minus => left_value - right_value,
        .Asterisk => left_value * right_value,
        .Slash => left_value / right_value,
        .Percent => @mod(left_value, right_value),
        else => @panic("Invalid operator of binary expression"),
    });
}

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
            const left_node = evaluate(node_props.left);
            const right_node = evaluate(node_props.right);

            return eval_binary_expr(left_node, right_node, node_props.operator);
        },
        .Number => {
            return RuntimeValue.mkNumber(node.props.?.Number.value);
        },
        else => {
            @panic("?");
        },
    };
}

pub fn run(source: []const u8) Parser.Errors![]u8 {
    const AST = try Parser.init(source);
    const rt = evaluate(&AST);

    return switch (rt.type) {
        .Number => try std.fmt.allocPrint(allocator, "{d}", .{rt.value.Number}),
        .Null => try std.fmt.allocPrint(allocator, "null", .{}),
        else => unreachable,
    };
}

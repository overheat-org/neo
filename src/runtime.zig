const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;
const Env = @import("./env.zig");

const Allocator = std.mem.Allocator;

const Errors = Parser.Errors;

const allocator = std.heap.page_allocator;

pub const RuntimeValue = struct {
    type: TokenTag,
    value: union {
        Number: f64,
        Null: u0,
        Boolean: u1,
        String: []u8,
    },

    pub inline fn mkBool(boolean: bool) RuntimeValue {
        return .{
            .type = TokenTag.Boolean,
            .value = .{ .Boolean = if (boolean) 1 else 0 },
        };
    }

    pub inline fn mkNumber(number: f64) RuntimeValue {
        return .{
            .type = TokenTag.Number,
            .value = .{ .Number = number },
        };
    }

    pub inline fn mkNull() RuntimeValue {
        return .{
            .type = TokenTag.Null,
            .value = .{ .Null = 0 },
        };
    }

    pub fn mkString(string: []u8) RuntimeValue {
        return .{
            .type = TokenTag.String,
            .value = .{ .String = string },
        };
    }
};

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}

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

            const comparation_type: Errors!TokenTag = (
                if (left_node.type == .Number and right_node.type == .Number) TokenTag.Number
                else if (left_node.type == .String and right_node.type == .String) TokenTag.String
                else TokenTag.Null
            );

            return RuntimeValue.mkBool(switch (node_props.operator) {
                .DoubleEqual => switch (comparation_type) {
                    .Number => left_node.value.Number == right_node.value.Number,
                    .String => std.mem.eql([]u8, left_node.value.String, right_node.value.String),
                    else => Errors.InvalidComparationType
                },
                .NotEqual => switch (comparation_type) {
                    .Number => left_node.value.Number != right_node.value.Number,
                    .String => !std.mem.eql([]u8, left_node.value.String, right_node.value.String),
                    else => Errors.InvalidComparationType
                },
                .GreaterEqual => switch (comparation_type) {
                    .Number => left_node.value.Number >= right_node.value.Number,
                    else => Errors.InvalidComparationType
                },
                .GreaterThan => switch (comparation_type) {
                    .Number => left_node.value.Number > right_node.value.Number,
                    else => Errors.InvalidComparationType
                },
                .LessEqual => switch (comparation_type) {
                    .Number => left_node.value.Number <= right_node.value.Number,
                    else => Errors.InvalidComparationType
                },
                .LessThan => switch (comparation_type) {
                    .Number => left_node.value.Number < right_node.value.Number,
                    else => Errors.InvalidComparationType
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

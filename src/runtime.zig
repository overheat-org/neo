const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;
const Env = @import("./env.zig");

const Allocator = std.mem.Allocator;

const Errors = Parser.Errors;

const Self = @This();

pub const RuntimeValue = struct {
    type: TokenTag,
    value: union { Number: f64, Null: u0, Boolean: u1 },

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
};

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}

// zig fmt: off
pub fn evaluate(self: Self, node: *const Node, env: *Env) Parser.Errors!RuntimeValue {
    return switch (node.kind) {
        .Program => {
            var last_evaluated: ?RuntimeValue = null;

            for (node.children) |statement| {
                last_evaluated = try evaluate(self, statement, env);
            }

            return last_evaluated orelse RuntimeValue.mkNull();
        },
        .BinaryExpression => {
            const node_props = node.props.?.BinaryExpression;
            const left_value = (try evaluate(self, node_props.left, env)).value.Number;
            const right_value = (try evaluate(self, node_props.right, env)).value.Number;

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
            const left_node = try evaluate(self, node_props.left, env);
            const right_node = try evaluate(self, node_props.right, env);

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
        .VarDeclaration => {
            const node_props = node.props.?.VarDeclaration;
            const id = node_props.id.props.?.Identifier.name;
            const value = try evaluate(self, node_props.value, env);

            try env.set(id, value);

            return RuntimeValue.mkNull();
        },
        .Identifier => {
            const node_props = node.props.?.Identifier;

            return env.get(node_props.name).?;
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

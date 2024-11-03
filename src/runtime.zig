const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;
const Env = @import("./env.zig");

const Errors = Parser.Errors || error{
    UnknownNode,
    UndefinedVariable,
    InvalidOperandType,
};

const Allocator = std.mem.Allocator;

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

const Self = @This();

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}

// zig fmt: off
pub fn evaluate(self: Self, node: *const Node, env: *Env) Errors!RuntimeValue {
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
            
            const left = try evaluate(self, node_props.left, env);
            const right = try evaluate(self, node_props.right, env);
            
            if (left.type != .Number or right.type != .Number) {
                return Errors.InvalidOperandType;
            }
            
            const left_value = left.value.Number;
            const right_value = right.value.Number;
            
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
                else if (left_node.type == .String and right_node.type == .String) TokenTag.String
                else TokenTag.Null
            );

            return RuntimeValue.mkBool(try switch (node_props.operator) {
                .DoubleEqual => switch (comparation_type) {
                    .Number => left_node.value.Number == right_node.value.Number,
                    .String => std.mem.eql(u8, left_node.value.String, right_node.value.String),
                    else => Errors.InvalidOperandType
                },
                .NotEqual => switch (comparation_type) {
                    .Number => left_node.value.Number != right_node.value.Number,
                    .String => !std.mem.eql(u8, left_node.value.String, right_node.value.String),
                    else => Errors.InvalidOperandType
                },
                .GreaterEqual => switch (comparation_type) {
                    .Number => left_node.value.Number >= right_node.value.Number,
                    else => Errors.InvalidOperandType
                },
                .GreaterThan => switch (comparation_type) {
                    .Number => left_node.value.Number > right_node.value.Number,
                    else => Errors.InvalidOperandType
                },
                .LessEqual => switch (comparation_type) {
                    .Number => left_node.value.Number <= right_node.value.Number,
                    else => Errors.InvalidOperandType
                },
                .LessThan => switch (comparation_type) {
                    .Number => left_node.value.Number < right_node.value.Number,
                    else => Errors.InvalidOperandType
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

            if (env.get(node_props.name)) |value| {
                return value;
            }

            return Errors.UndefinedVariable;
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

const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;
const Env = @import("./env.zig");
const VesperError = @import("./reporter.zig");
const Allocator = std.mem.Allocator;

pub const RuntimeValue = struct {
    type: TokenTag,
    value: union {
        Number: f64,
        Null: u0,
        Boolean: u1,
        String: []const u8,
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

    pub fn mkString(allocator: Allocator, string: []const u8) RuntimeValue {
        defer allocator.free(string);

        std.debug.print("\n\n{any}\n\n", .{string});

        const dupe_str = allocator.dupe(u8, string) catch |e| VesperError.throw(.{
            .err = .InternalError,
            .meta = .{ .exception = @errorName(e) },
        });

        return .{
            .type = TokenTag.String,
            .value = .{ .String = dupe_str },
        };
    }
};

const Self = @This();

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    VesperError.init(allocator);

    return Self{
        .allocator = allocator,
    };
}

// zig fmt: off
pub fn evaluate(self: Self, node: *const Node, env: *Env) RuntimeValue {    
    return switch (node.kind) {
        .Program, .Block => {
            var last_evaluated: ?RuntimeValue = null;

            for (node.children) |statement| {
                last_evaluated = evaluate(self, statement, env);
            }

            return last_evaluated orelse RuntimeValue.mkNull();
        },
        .BinaryExpression => {
            const node_props = node.props.?.BinaryExpression;
            
            const left_node = evaluate(self, node_props.left, env);
            const right_node = evaluate(self, node_props.right, env);
            
            const err = VesperError.new(.TypeMismatch, node.span, .{ .expected = "Number", .found = @tagName(node.kind) });
            const binary_type: TokenTag = (
                if (left_node.type == .Number and right_node.type == .Number) TokenTag.Number
                else if (left_node.type == .String and right_node.type == .String) TokenTag.String
                else TokenTag.Null
            );
            
            const left_value = left_node.value;
            const right_value = right_node.value;

            return switch (node_props.operator) {
                .Plus => switch (binary_type) {
                    .Number => RuntimeValue.mkNumber(left_value.Number + right_value.Number),
                    .String => {
                        const concatenated = std.mem.concat(self.allocator, u8, &.{ left_value.String, right_value.String })
                            catch VesperError.throw(.{ .err = .OutOfMemory, .span = node.span, .meta = .{} });
                        return RuntimeValue.mkString(self.allocator, concatenated);
                    },
                    else => VesperError.throw(err) 
                },
                .Minus => RuntimeValue.mkNumber(left_value.Number - right_value.Number),
                .Asterisk => RuntimeValue.mkNumber(left_value.Number * right_value.Number),
                .Slash => 
                    if(right_value.Number != 0) RuntimeValue.mkNumber(left_value.Number / right_value.Number)
                    else VesperError.throw(.{ .err = .DivisionByZero, .span = node.span, .meta = .{} }),
                .Percent => 
                    if(right_value.Number != 0) RuntimeValue.mkNumber(@mod(left_value.Number, right_value.Number))
                    else VesperError.throw(.{ .err = .DivisionByZero, .span = node.span, .meta = .{} }),
                else => unreachable,
            };
        },
        .ComparationExpression => {
            const node_props = node.props.?.ComparationExpression;
            const left_node = evaluate(self, node_props.left, env);
            const right_node = evaluate(self, node_props.right, env);

            const comparation_type: TokenTag = (
                if (left_node.type == .Number and right_node.type == .Number) TokenTag.Number
                else if (left_node.type == .String and right_node.type == .String) TokenTag.String
                else TokenTag.Null
            );

            const err = VesperError.new(
                .TypeMismatch, 
                .{ .line = 0, .column = 0 }, 
                .{ .expected = "Number", .found = @tagName(comparation_type) }
            );

            const boolean: bool = switch (node_props.operator) {
                .DoubleEqual => switch (comparation_type) {
                    .Number => left_node.value.Number == right_node.value.Number,
                    .String => std.mem.eql(u8, left_node.value.String, right_node.value.String),
                    else => VesperError.throw(err)
                },
                .NotEqual => switch (comparation_type) {
                    .Number => left_node.value.Number != right_node.value.Number,
                    .String => !std.mem.eql(u8, left_node.value.String, right_node.value.String),
                    else => VesperError.throw(err)
                },
                .GreaterEqual => 
                    if(comparation_type == .Number) left_node.value.Number >= right_node.value.Number 
                    else VesperError.throw(err),
                .GreaterThan => 
                    if(comparation_type == .Number) left_node.value.Number > right_node.value.Number
                    else VesperError.throw(err),
                .LessEqual => 
                    if(comparation_type == .Number) left_node.value.Number <= right_node.value.Number
                    else VesperError.throw(err),
                .LessThan => 
                    if(comparation_type == .Number) left_node.value.Number < right_node.value.Number
                    else VesperError.throw(err),
                else => unreachable
            };

            return RuntimeValue.mkBool(boolean);
        },
        .If => {
            const node_props = node.props.?.If;
            const expect = evaluate(self, node_props.expect, env);
            
            if(expect.value.Boolean == 1) {
                return evaluate(self, node_props.then, env);
            } else {
                if(node_props.else_stmt) |stmt| return evaluate(self, stmt, env);
            }

            return RuntimeValue.mkNull();
        },
        .VarDeclaration => {
            const node_props = node.props.?.VarDeclaration;
            const id = node_props.id.props.?.Identifier.name;
            const value = evaluate(self, node_props.value, env);

            std.debug.print("\n\nID: {s}\n", .{id});
            env.set(id, value) catch |e| VesperError.throw(.{
                .err = .InternalError,
                .span = .{},
                .meta = .{ .exception = @errorName(e) },
            });

            return RuntimeValue.mkNull();
        },
        .Identifier => {
            const node_props = node.props.?.Identifier;

            if (env.get(node_props.name)) |value| {
                return value;
            }

            VesperError.throw(.{ .err = .UndefinedVariable, .span = node.span, .meta = .{ .variable = node_props.name } });
        },
        .Number => {
            return RuntimeValue.mkNumber(node.props.?.Number.value);
        },
        .String => {
            return RuntimeValue.mkString(self.allocator, node.props.?.String.value);
        },
        else => VesperError.throw(.{ .err = .UnknownNode, .span = node.span, .meta = .{ .node = @tagName(node.kind) }}),
    };
}
// zig fmt: on

const std = @import("std");
const Parser = @import("./parser.zig");
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const _token = @import("./token.zig");
const TokenTag = _token.Tag;
const Env = @import("./env.zig");
const Span = _token.Span;

const RuntimeErrors = enum {
    InternalError,
    SyntaxError,
    DivisionByZero,
    TypeMismatch,
    UnknownNode,
    UndefinedVariable,
    InvalidExpression,
};

const VesperError = struct {
    var allocator: Allocator = undefined;
    err: RuntimeErrors,
    span: Span,
    meta: std.StaticStringMap([]const u8),

    pub inline fn init(_allocator: Allocator) void {
        allocator = _allocator;
    }

    pub inline fn new(err: RuntimeErrors, span: Span, meta: anytype) VesperError {
        const meta_info = @typeInfo(@TypeOf(meta)).Struct;
        const fields = meta_info.fields;

        const slice = allocator.alloc([2][]const u8, fields.len) catch unreachable;

        comptime var i = 0;
        inline for (fields) |field| {
            slice[i] = .{ field.name, @field(meta, field.name) };

            i += 1;
        }

        // const _meta = std.StaticStringMap([]const u8).init(slice, allocator) catch unreachable;

        return VesperError{ .err = err, .span = span, .meta = .{} };
    }

    pub fn throw(e: anytype) noreturn {
        VesperError._throw(e) catch {};

        std.process.exit(1);
    }

    fn _throw(_error: anytype) !void {
        const e = if (@TypeOf(_error) != VesperError) VesperError.new(_error.err, .{ .line = 0, .column = 0 }, _error.meta) else _error;

        const stdout = std.io.getStdOut().writer();

        // try stdout.print("Error in file '{s}' at line {d}, column {d}: ", .{
        //     e.span.file, e.span.line, e.span.column,
        // });

        switch (e.err) {
            .InternalError => {
                try stdout.print("Internal Error: '{s}'", .{e.meta.get("exception").?});
            },
            .SyntaxError => {
                try stdout.print("Syntax Error", .{});

                if (e.meta.has("expected")) {
                    try stdout.print(": expected '{s}'", .{e.meta.get("expected").?});
                }
                if (e.meta.has("found")) {
                    try stdout.print(", but found '{s}'", .{e.meta.get("found").?});
                }
            },
            .DivisionByZero => {
                try stdout.print("Division by Zero Error", .{});
            },
            .TypeMismatch => {
                try stdout.print("Type Mismatch Error", .{});

                if (e.meta.has("expected")) {
                    try stdout.print(": expected type '{s}'", .{e.meta.get("expected").?});
                }
                if (e.meta.has("found")) {
                    try stdout.print(", but found type '{s}'", .{e.meta.get("found").?});
                }
            },
            .UndefinedVariable => {
                try stdout.print("Undefined Variable Error", .{});

                if (e.meta.has("variable")) {
                    try stdout.print(": variable '{s}' is not defined", .{e.meta.get("variable").?});
                }
            },
            .UnknownNode => {
                try stdout.print("Unknown Node: '{s}'", .{e.meta.get("node").?});
            },
            else => {
                try stdout.print("Unknown Error", .{});
            },
        }

        try stdout.print("\n", .{});
    }
};

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
            
            const left = evaluate(self, node_props.left, env);
            const right = evaluate(self, node_props.right, env);
            
            if (left.type != .Number or right.type != .Number) {
                VesperError.throw(.{ 
                    .err = .TypeMismatch, 
                    .span = node.span, 
                    .meta = .{ .expected = "Number", .found = @tagName(node.kind) } 
                });
            }
            
            const left_value = left.value.Number;
            const right_value = right.value.Number;
            
            return RuntimeValue.mkNumber(switch (node_props.operator) {
                .Plus => left_value + right_value,
                .Minus => left_value - right_value,
                .Asterisk => left_value * right_value,
                .Slash => 
                    if(right_value != 0) left_value / right_value
                    else VesperError.throw(.{ .err = .DivisionByZero, .span = node.span, .meta = .{} }),
                .Percent => 
                    if(right_value != 0) @mod(left_value, right_value)
                    else VesperError.throw(.{ .err = .DivisionByZero, .span = node.span, .meta = .{} }),
                else => unreachable,
            });
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

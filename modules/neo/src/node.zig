const std = @import("std");
const _token = @import("./token.zig");
const parser = @import("./parser.zig");
const TokenTag = _token.Tag;
const Span = _token.Span;
const NeoError = @import("./reporter.zig");
const utils = @import("./utils.zig");
const format = utils.format;

const Node = @This();

/// TODO: make this more flexible
const allocator = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

span: Span = Span{ .column = 0, .line = 0 },
kind: Kind,
props: Properties,
children: []*Node = &.{},

pub fn new(comptime kind: Kind, prop: std.meta.TagPayload(Properties, kind)) *Node {
    const current = allocator.create(Node) catch NeoError.throw(.{ .err = .OutOfMemory });
    current.* = Node{
        .kind = kind,
        .props = @unionInit(Properties, @tagName(kind), prop),
    };

    return current;
}

pub fn destroy(self: *Node) void {
	allocator.destroy(self);
}

pub fn print(self: Node) void {
    std.debug.print("Node{\n", .{});
    std.debug.print("\tkind: {s}\n", .{self.kind});

    {
        const union_props_info = @typeInfo(@TypeOf(self.props));
        const fields = union_props_info.@"union".fields;
        inline for (fields) |field| {
            const key = field.name;
            if (key != @tagName(self.kind)) continue;

            // const value = @field(self.props, key);

        }
    }

    const props = @field(self.props, @tagName(self.kind));
    const props_info = @typeInfo(@TypeOf(props));
    if (props_info.@"struct" == null) {
        @compileError("Cannot print props of Node");
    }
    const fields = props_info.@"struct".fields;

    inline for (fields) |field| {
        const key = field.name;
        const value = @field(props, key);
        std.debug.print("\t{s}: {any}\n", .{ key, value });
    }

    std.debug.print("}\n", .{});
}

pub const Kind = enum {
    Program,
    VarDeclaration,
    Identifier,
    String,
    Number,
    Boolean,
    Block,
    If,
    ObjectExpression,
    ObjectProperty,
    Null,
    AssignmentExpression,
    ComparationExpression,
    BinaryExpression,
    MemberAccessExpression,
};

pub const Properties = union(Kind) {
    Program: void,
    VarDeclaration: VarDeclaration,
    Identifier: Identifier,
    String: String,
    Number: Number,
    Boolean: Boolean,
    Block: struct {},
    If: If,
    ObjectExpression: ObjectExpression,
    ObjectProperty: ObjectProperty,
    Null: struct {},
    AssignmentExpression: AssignmentExpression,
    ComparationExpression: ComparationExpression,
    BinaryExpression: BinaryExpression,
    MemberAccessExpression: MemberAccessExpression,
};

pub const Identifier = struct {
    name: []const u8,
};

pub const VarDeclaration = struct {
    id: *Node,
    value: *Node,
    constant: bool,
};

pub const String = struct {
    value: []const u8,
};

pub const Number = struct {
    value: f64,
};

pub const Boolean = struct {
    value: u1,
};

pub const If = struct {
    expect: *Node,
    then: *Node,
    children: ?*Node,
};

pub const ObjectExpression = struct {
    properties: std.AutoHashMap(*Node, *Node),
};

pub const ObjectProperty = struct {
    key: *Node,
    value: *Node,
};

pub const BinaryExpression = struct {
    left: *Node,
    right: *Node,
    operator: TokenTag,
};

pub const ComparationExpression = struct {
    left: *Node,
    right: *Node,
    operator: TokenTag,
};

pub const AssignmentExpression = struct {
    left: *Node,
    right: *Node,
    operator: TokenTag,
};

pub const MemberAccessExpression = struct { 
    object: *Node, 
    property: *Node, 
    meta: bool, 
};

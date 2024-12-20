const std = @import("std");
const _token = @import("./token.zig");
const parser = @import("./parser.zig");
const TokenTag = _token.Tag;
const Span = _token.Span;

/// List of Node pointers that needs to be deallocated
pub var node_ptrs_list: std.ArrayList(*Node) = undefined;
const allocator = std.heap.page_allocator;
const Allocator = std.mem.Allocator;

pub const Node = struct {
    span: Span = Span{ .column = 0, .line = 0 },
    kind: Kind,
    props: ?Properties = null,
    children: []*const Node = &.{},

    pub inline fn new(node: Node) Allocator.Error!*Node {
        const current = try allocator.create(Node);

        current.* = node;
        try node_ptrs_list.append(current);

        return current;
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
    };

    pub const Properties = union(Kind) {
        Program: void,
        VarDeclaration: VarDeclaration,
        Identifier: Identifier,
        String: String,
        Number: Number,
        Boolean: Boolean,
        Block: void,
        If: If,
        ObjectExpression: ObjectExpression,
        ObjectProperty: ObjectProperty,
        Null: void,
        AssignmentExpression: AssignmentExpression,
        ComparationExpression: ComparationExpression,
        BinaryExpression: BinaryExpression,
    };
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
    else_stmt: ?*Node,
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

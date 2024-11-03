const std = @import("std");
const _token = @import("./token.zig");
const parser = @import("./parser.zig");
const TokenTag = _token.Tag;

/// List of Node pointers that needs to be deallocated
pub var node_ptrs_list: std.ArrayList(*const Node) = undefined;
const allocator = std.heap.page_allocator;

pub const Node = struct {
    kind: Kind,
    props: ?Properties,
    children: []*const Node = &.{},

    pub inline fn init(node: Node) Node {
        const current = try allocator.create(Node);

        current.* = node;
        node_ptrs_list.append(current) catch @panic("Cannot register token to be deallocated");

        return current;
    }

    pub const Kind = enum {
        Program,
        VarDeclaration,
        Identifier,
        Number,
        Object,
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
        Number: Number,
        Object: Object,
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

pub const Number = struct {
    value: f64,
};

pub const Object = struct {
    properties: []*Node,
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

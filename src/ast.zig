const _token = @import("./token.zig");
const TokenTag = _token.Tag;

pub const Node = struct {
    kind: Kind,
    props: ?Properties,
    children: []*const Node = &.{},

    pub const Kind = enum {
        Program,
        VarDeclaration,
        Identifier,
        Number,
        AssignmentExpression,
        BinaryExpression,
    };

    pub const Properties = union(Kind) {
        Program: void,
        VarDeclaration: VarDeclaration,
        Identifier: Identifier,
        Number: Number,
        AssignmentExpression: AssignmentExpression,
        BinaryExpression: BinaryExpression,
    };
};

pub const Identifier = struct {
    name: []const u8,
};

pub const VarDeclaration = struct {
    id: []const u8,
};

pub const Number = struct {
    value: f64,
};

pub const BinaryExpression = struct {
    left: *Node,
    right: *Node,
    operator: TokenTag,
};

pub const AssignmentExpression = struct {
    left: *Node,
    right: *Node,
    operator: TokenTag,
};

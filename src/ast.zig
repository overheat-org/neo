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
        String,
        Number,
        Boolean,
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
        AssignmentExpression: AssignmentExpression,
        ComparationExpression: ComparationExpression,
        BinaryExpression: BinaryExpression,
    };
};

pub const Identifier = struct {
    name: []const u8,
};

pub const VarDeclaration = struct {
    id: []const u8,
};

pub const String = struct {
    value: []u8,
};

pub const Number = struct {
    value: f64,
};

pub const Boolean = struct {
    value: u1,
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

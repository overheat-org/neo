pub const Node = struct {
    kind: Kind,
    children: []*const Node,
    props: Properties,

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

    pub fn init(kind: Kind) Node {
        return Node{
            .kind = kind,
            .props = undefined,
            .children = &[_]*const Node{},
        };
    }
};

pub const Identifier = struct { name: []const u8 };
pub const VarDeclaration = struct { id: []const u8 };
pub const Number = struct { value: f64 };
pub const BinaryExpression = struct { left: *Node, right: *Node, operator: []const u8 };
pub const AssignmentExpression = struct { left: *Node, right: *Node, operator: []const u8 };

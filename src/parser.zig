const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("./lexer.zig");
const Token = @import("./token.zig");
const TokenTag = Token.Tag;
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const AssignmentExpression = _ast.AssignmentExpression;
const BinaryExpression = _ast.BinaryExpression;
const Ast = @import("./ast.zig");

const Self = @This();

pub const Errors = Lexer.Errors || std.mem.Allocator.Error || error{
    UnknownToken,
};

const Reader = struct {
    offset: usize,
    tokens: *std.ArrayList(Token),

    fn init(tokens: *std.ArrayList(Token)) Reader {
        return Reader{
            .offset = 0,
            .tokens = tokens,
        };
    }

    inline fn curr(self: *Reader) ?Token {
        if (self.offset >= self.tokens.items.len) {
            return null;
        }

        return self.tokens.items[self.offset];
    }

    inline fn peek(self: *Reader) ?Token {
        if (self.offset + 1 >= self.tokens.items.len) {
            return null;
        }

        return self.tokens.items[self.offset + 1];
    }

    inline fn next(self: *Reader) Token {
        if (self.offset + 1 >= self.tokens.items.len) {
            return self.tokens.items[self.offset]; // Returing EOF
        }

        self.offset += 1;

        return self.tokens.items[self.offset];
    }

    inline fn expect(self: *Reader, comptime tags: []const Token.Tag, comptime string: []const u8) !void {
        const token = self.curr().?;
        for (tags) |tag| {
            if (tag == token.tag) return;
        }

        @panic(string);
    }

    inline fn not_eof(self: *Reader) bool {
        return if (self.curr()) |c| c.tag != TokenTag.EOF else false;
    }
};

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    Ast.node_ptrs_list = std.ArrayList(*Node).init(allocator);

    return Self{
        .allocator = allocator,
    };
}

pub fn parse(self: Self, source: []const u8) !Node {
    var tokens = try Lexer.init(source);
    defer tokens.deinit();

    var src = Reader.init(&tokens);

    var program_children = std.ArrayList(*Node).init(self.allocator);
    defer program_children.deinit();

    while (src.not_eof()) {
        const stmt = try parse_stmt(self, &src);

        try program_children.append(stmt);
    }

    return Node{
        .kind = .Program,
        .children = try program_children.toOwnedSlice(),
        .props = null,
    };
}

pub fn deinit(self: Self) void {
    for (Ast.node_ptrs_list.items) |item| {
        self.allocator.destroy(item);
    }

    Ast.node_ptrs_list.deinit();
}

fn parse_stmt(self: Self, src: *Reader) Errors!*Node {
    return switch (src.curr().?.tag) {
        .LeftBrace => parse_block(self, src),
        .Var, .Const => parse_var_decl(self, src),
        .If => parse_if_stmt(self, src),
        else => try parse_expr(self, src),
    };
}

fn parse_var_decl(self: Self, src: *Reader) Errors!*Node {
    const keyword = src.next();
    const is_const = keyword.tag == .Const;

    const identifierNode = try parse_primary_expr(self, src);
    try src.expect(&.{ .Equal, .SemiColon }, "Expecting semi-colon or equal");
    const token = src.curr().?;
    _ = src.next();

    return try Node.new(.{
        .kind = .VarDeclaration,
        .props = .{
            .VarDeclaration = .{
                .id = identifierNode,
                .value = if (token.tag == .Equal) try parse_expr(self, src) else try Node.new(.{ .kind = .Null }),
                .constant = is_const,
            },
        },
    });
}

fn parse_if_stmt(self: Self, src: *Reader) Errors!*Node {
    const _if = src.next();

    try src.expect(&.{.LeftParen}, "Expecting '('");
    _ = src.next();

    const expect = try parse_expr(self, src);

    try src.expect(&.{.RightParen}, "Expecting ')'");
    _ = src.next();

    const then = try parse_expr(self, src);

    var else_stmt: ?*Node = null;

    if (src.curr().?.tag == .Else) {
        _ = src.next();

        if (src.curr().?.tag == .If) {
            else_stmt = try parse_if_stmt(self, src);
        } else {
            else_stmt = try parse_expr(self, src);
        }
    }

    return try Node.new(.{
        .kind = .If,
        .props = .{
            .If = .{
                .expect = expect,
                .then = then,
                .else_stmt = else_stmt,
            },
        },
        .span = _if.span,
    });
}

fn parse_expr(self: Self, src: *Reader) Errors!*Node {
    return switch (src.curr().?.tag) {
        .LeftBrace => parse_block(self, src),
        else => try parse_object_expr(self, src),
    };
}

fn parse_block(self: Self, src: *Reader) Errors!*Node {
    const _block = src.next();
    var stmts_list = std.ArrayList(*Node).init(self.allocator);

    while (src.curr().?.tag != .RightBrace) {
        try stmts_list.append(try parse_stmt(self, src));
    }

    _ = src.next();

    return Node.new(.{ .kind = .Block, .children = try stmts_list.toOwnedSlice(), .span = _block.span });
}

inline fn parse_string_expr(_: Self, src: *Reader) Errors!*Node {
    const curr = src.curr();
    _ = src.next();

    return try Node.new(.{ .kind = .String, .props = .{ .String = .{ .value = curr.?.value.?.string } } });
}

fn parse_object_expr(self: Self, src: *Reader) Errors!*Node {
    const _object = src.curr();

    if (_object.?.tag != .LeftBrace) return parse_comparation_expr(self, src);

    _ = src.next();

    var props = std.AutoHashMap(*Node, *Node).init(self.allocator);

    while (src.not_eof() and src.curr().?.tag != .RightBrace) {
        try src.expect(&.{.Identifier}, "Object literal key expected");
        const key = try parse_primary_expr(self, src);

        try src.expect(&.{.Equal}, "Missing colon following Identifier in Object Expression");
        const value = try parse_expr(self, src);

        try props.put(key, value);
    }

    return Node.new(.{
        .kind = .ObjectExpression,
        .props = .{
            .ObjectExpression = .{ .properties = props },
        },
        .span = _object.?.span,
    });
}

fn parse_comparation_expr(self: Self, src: *Reader) Errors!*Node {
    const left = try parse_additive_expr(self, src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    return switch (operator) {
        .Equal => {
            const _eq = src.next();

            const right = try parse_primary_expr(self, src);

            return Node.new(.{
                .kind = .AssignmentExpression,
                .props = .{
                    .AssignmentExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
                .span = _eq.span,
            });
        },
        .LessEqual, .LessThan, .GreaterThan, .GreaterEqual, .NotEqual, .DoubleEqual => {
            const _comparation = src.next();

            const right = try parse_primary_expr(self, src);

            return Node.new(.{
                .kind = .ComparationExpression,
                .props = .{
                    .ComparationExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
                .span = _comparation.span,
            });
        },
        else => left,
    };
}

fn parse_additive_expr(self: Self, src: *Reader) Errors!*Node {
    var left = try parse_multiplicitave_expr(self, src);

    var operator = src.curr().?.tag;

    while (operator == .Plus or operator == .Minus) {
        const _expr = src.next();

        const right = try parse_multiplicitave_expr(self, src);

        left = try Node.new(.{ .kind = .BinaryExpression, .props = .{
            .BinaryExpression = .{
                .left = left,
                .operator = operator,
                .right = right,
            },
        }, .span = _expr.span });

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_multiplicitave_expr(self: Self, src: *Reader) Errors!*Node {
    var left = try parse_primary_expr(self, src);

    var operator = src.curr().?.tag;

    while (operator == .Slash or
        operator == .Asterisk or
        operator == .Percent)
    {
        const _expr = src.next();

        const right = try parse_primary_expr(self, src);

        left = try Node.new(.{
            .kind = .BinaryExpression,
            .props = .{
                .BinaryExpression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
            .span = _expr.span,
        });

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_primary_expr(self: Self, src: *Reader) Errors!*Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Identifier => {
            const _id = src.next();

            return try Node.new(.{
                .kind = .Identifier,
                .props = .{
                    .Identifier = .{
                        .name = current.value.?.string,
                    },
                },
                .span = _id.span,
            });
        },
        .String => parse_string_expr(self, src),
        .Number => {
            const _number = src.next();

            return try Node.new(.{
                .kind = .Number,
                .props = .{
                    .Number = .{
                        .value = current.value.?.number,
                    },
                },
                .span = _number.span,
            });
        },
        .LeftParen => {
            _ = src.next();

            const value = try parse_expr(self, src);

            _ = try src.expect(&.{.RightParen}, "Expecting \")\"");
            _ = src.next();

            return value;
        },
        else => {
            std.debug.print("{any}\n", .{src.curr()});

            return Errors.UnknownToken;
        },
    };
}

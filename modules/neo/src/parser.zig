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
const NeoError = @import("./reporter.zig");

const Self = @This();

pub const Errors = std.mem.Allocator.Error || error { _ };

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

    fn expect(self: *Reader, comptime tags: []const Token.Tag, comptime string: []const u8) void {
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

pub fn parse(self: Self, source: []const u8) Node {
    var tokens = Lexer.init(source);
    defer tokens.deinit();

    var src = Reader.init(&tokens);

    var program_children = std.ArrayList(*Node).init(self.allocator);
    defer program_children.deinit();

    while (src.not_eof()) {
        const stmt = parse_stmt(self, &src);

        program_children.append(stmt) catch |e| NeoError.throw(e);
    }

    return Node{
        .kind = .Program,
        .children = program_children.toOwnedSlice() catch |e| NeoError.throw(e),
        .props = null,
    };
}

pub fn deinit(self: Self) void {
    for (Ast.node_ptrs_list.items) |item| {
        self.allocator.destroy(item);
    }

    Ast.node_ptrs_list.deinit();
}

fn parse_stmt(self: Self, src: *Reader) *Node {
    return try switch (src.curr().?.tag) {
        .LeftBrace => parse_block(self, src),
        .Var, .Const => parse_var_decl(self, src),
        .If => parse_if_stmt(self, src),
        else => parse_expr(self, src),
    };
}

fn parse_var_decl(self: Self, src: *Reader) *Node {
    const keyword = src.next();
    const is_const = keyword.tag == .Const;

    const identifierNode = parse_primary_expr(self, src);
    src.expect(&.{ .Equal, .SemiColon }, "Expecting semi-colon or equal");
    const token = src.curr().?;
    _ = src.next();

    return Node.new(.{
        .kind = .VarDeclaration,
        .props = .{
            .VarDeclaration = .{
                .id = identifierNode,
                .value = if (token.tag == .Equal) parse_expr(self, src) else Node.new(.{ .kind = .Null }),
                .constant = is_const,
            },
        },
    });
}

fn parse_if_stmt(self: Self, src: *Reader) *Node {
    const _if = src.next();

    src.expect(&.{.LeftParen}, "Expecting '('");
    _ = src.next();

    const expect = parse_expr(self, src);

    src.expect(&.{.RightParen}, "Expecting ')'");
    _ = src.next();

    const then = parse_expr(self, src);

    var else_stmt: ?*Node = null;

    if (src.curr().?.tag == .Else) {
        _ = src.next();

        if (src.curr().?.tag == .If) {
            else_stmt = parse_if_stmt(self, src);
        } else {
            else_stmt = parse_expr(self, src);
        }
    }

    return Node.new(.{
        .kind = .If,
        .props = .{
            .If = .{
                .expect = expect,
                .then = then,
                .children = else_stmt,
            },
        },
        .span = _if.span,
    });
}

fn parse_expr(self: Self, src: *Reader) *Node {
    return switch (src.curr().?.tag) {
        .LeftBrace => parse_block(self, src),
        else => parse_object_expr(self, src),
    };
}

fn parse_block(self: Self, src: *Reader) *Node {
    const _block = src.next();
    var stmts_list = std.ArrayList(*Node).init(self.allocator);

    while (src.curr().?.tag != .RightBrace) {
        stmts_list.append(parse_stmt(self, src)) catch |e| NeoError.throw(e);
    }

    _ = src.next();

    return Node.new(.{ .kind = .Block, .children = stmts_list.toOwnedSlice(), .span = _block.span });
}

inline fn parse_string_expr(_: Self, src: *Reader) *Node {
    const curr = src.curr();
    _ = src.next();

    return Node.new(.{ .kind = .String, .props = .{ .String = .{ .value = curr.?.value.?.string } } });
}

fn parse_object_expr(self: Self, src: *Reader) *Node {
    const _object = src.curr();

    if (_object.?.tag != .LeftBrace) return parse_comparation_expr(self, src);

    _ = src.next();

    var props = std.AutoHashMap(*Node, *Node).init(self.allocator);

    while (src.not_eof() and src.curr().?.tag != .RightBrace) {
        src.expect(&.{.Identifier}, "Object literal key expected");
        const key = parse_primary_expr(self, src);

        src.expect(&.{.Equal}, "Missing colon following Identifier in Object Expression");
        const value = parse_expr(self, src);

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

fn parse_member_access_expr(self: Self, src: *Reader) *Node {
	const left = parse_expr(self, src);
	const operator = src.next().tag;
	const right = parse_identifier(self, src);

	return Node.new(.MemberAccessExpression, .{
		.object = left,
		.property = right,
		.meta = operator == .Colon
	});
}

fn parse_comparation_expr(self: Self, src: *Reader) *Node {
    const left = parse_additive_expr(self, src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    return switch (operator) {
        .Equal => {
            const _eq = src.next();

            const right = parse_primary_expr(self, src);

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

            const right = parse_primary_expr(self, src);

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

fn parse_additive_expr(self: Self, src: *Reader) *Node {
    var left = parse_multiplicitave_expr(self, src);

    var operator = src.curr().?.tag;

    while (operator == .Plus or operator == .Minus) {
        const _expr = src.next();

        const right = parse_multiplicitave_expr(self, src);

        left = Node.new(.{ .kind = .BinaryExpression, .props = .{
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

fn parse_multiplicitave_expr(self: Self, src: *Reader) *Node {
    var left = parse_primary_expr(self, src);

    var operator = src.curr().?.tag;

    while (operator == .Slash or
        operator == .Asterisk or
        operator == .Percent)
    {
        const _expr = src.next();

        const right = parse_primary_expr(self, src);

        left = Node.new(.{
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

inline fn parse_number_expr(_: Self, src: *Reader) Errors!*Node {
    const _number = src.next();

    return Node.new(.{
        .kind = .Number,
        .props = .{
            .Number = .{
                .value = src.curr().?.value.?.number,
            },
        },
        .span = _number.span,
    });
}

inline fn parse_identifier(_: Self, src: *Reader) *Node {
    const _id = src.next();
	const next_node = src.peek();

	if(next_node and (
		next_node.?.tag == .Dot or
		next_node.?.tag == .Colon
	)) {
		return parse_member_access_expr(Self, src);
	}

    return Node.new(.{
        .kind = .Identifier,
        .props = .{
            .Identifier = .{
                .name = src.curr().?.value.?.string,
            },
        },
        .span = _id.span,
    });
}

inline fn parse_paren(self: Self, src: *Reader) *Node {
    _ = src.next();

    const value = parse_expr(self, src);

    _ = src.expect(&.{.RightParen}, "Expecting \")\"");
    _ = src.next();

    return value;
}

fn parse_primary_expr(self: Self, src: *Reader) *Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Identifier => parse_identifier(self, src),
        .String => parse_string_expr(self, src),
        .Number => parse_number_expr(self, src),
        .LeftParen => parse_paren(self, src),
        else => NeoError.throw(.{
            .err = .SyntaxError,
            .meta = .{ .character = @tagName(current.tag) }
        }),
    };
}

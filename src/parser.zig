const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("./lexer.zig");
const Token = @import("./token.zig");
const TokenTag = Token.Tag;
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const AssignmentExpression = _ast.AssignmentExpression;
const BinaryExpression = _ast.BinaryExpression;
const VesperError = @import("./reporter.zig");

const Self = @This();

allocator: Allocator,

inline fn not_eof(self: Self) bool {
	return self.src.curr().?.tag != .EOF;
}

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}

pub fn parse(self: Self, source: []const u8) Node {
    var lexer = Lexer.init(source);
    defer lexer.deinit();

    var program_children = std.ArrayList(*Node).init(self.allocator);
    defer program_children.deinit();

    while (self.not_eof()) {
       const stmt = parse_stmt(self, &lexer);

        program_children.append(stmt);
    }

    return Node{
        .kind = .Program,
        .children = program_children.toOwnedSlice(),
        .props = null,
    };
}

fn parse_stmt(self: Self, src: *Lexer) *Node {
    return switch (src.current.?.tag) {
		.Con => parse_con_stmt(self, src),
		.Var => parse_var_stmt(self, src),
        .If => parse_if_stmt(self, src),
		.Match => parse_match(self, src),
		.While => parse_while_stmt(self, src),
		.For => parse_for_stmt(self, src),
		.Fn => parse_fn_stmt(self, src),
		.Class => parse_class_stmt(self, src),
        else => parse_expr(self, src),
    };
}

fn parse_con_stmt(self: Self, src: *Lexer) *Node {
	return self.make_node(
		.Con, 
		.{ .expr = parse_assignment_expr(self, src)
	});
}

fn parse_var_stmt(self: Self, src: *Lexer) *Node {
	return self.make_node(
		.Var, 
		.{ .expr = parse_assignment_expr(self, src)
	});
}

fn parse_if_stmt(self: Self, src: *Lexer) *Node {
	self.expect(.LeftParen);
    const expect = self.parse_expr(src);
	self.expect(.RightParen);

    const then = self.parse_expr_until_end(src);

    var else_stmt: ?*Node = null;

    if (src.curr.tag == .Else) {
        _ = src.next();

        if (src.curr.tag == .If) {
            else_stmt = self.parse_if_stmt(src);
        } else {
			self.expect(.Colon);
			src.next();

            else_stmt = self.parse_expr(src);
        }
    }

    return self.make_node(
		.If,
		.{
			.expect = expect,
			.then = then,
			.children = else_stmt,
		},
    );
}

fn parse_while_stmt(self: Self, src: *Lexer) *Node {
	const expect = self.parse_expr(src);
	const body = self.parse_expr(src);

	return self.make_node(
		.While,
		.{
			.expect = expect,
			.body = body,
		},
	);
}

fn parse_expr(self: Self, src: *Lexer) *Node {
    return switch (src.curr().?.tag) {
        else => parse_object_expr(self, src),
    };
}

inline fn parse_string_expr(_: Self, src: *Lexer) *Node {
    const curr = src.curr();
    _ = src.next();

    return Node.new(.String, .{ .value = curr.?.value.?.string });
}

fn parse_object_expr(self: Self, src: *Lexer) *Node {
    const _object = src.curr();

    if (_object.?.tag != .LeftBrace) return parse_comparation_expr(self, src);

    _ = src.next();

    var props = NodeMap.init(self.allocator);

    while (src.not_eof() and src.curr().?.tag != .RightBrace) {
        src.expect(&.{.Identifier}, "Object literal key expected");
        const key = parse_primary_expr(self, src);

        src.expect(&.{.Equal}, "Missing colon following Identifier in Object Expression");
        const value = parse_expr(self, src);

        props.put(key, value);
    }

    const node = Node.new(
		.ObjectExpression,
        .{ .properties = props },
    );

	node.span = _object.?.span;

	return node;
}

fn parse_member_access_expr(self: Self, src: *Lexer) *Node {
	const left = self.parse_expr(src);
	const operator = src.next().tag;
	const right = self.parse_identifier(src);

	return self.make_node(.MemberAccessExpression, .{
		.object = left,
		.property = right,
		.meta = operator == .Colon
	});
}

fn parse_assignment_expr(self: Self, src: *Lexer) *Node {
	const left = parse_additive_expr(self, src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

	return switch (operator) {
		.Equal => {
            const right = parse_primary_expr(self, src);

            return self.make_node(
                .AssignmentExpression,
                .{
					.left = left,
					.operator = operator,
					.right = right,
                },
            );
        },
	};
}

fn parse_comparation_expr(self: Self, src: *Lexer) *Node {
    const left = parse_additive_expr(self, src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    return switch (operator) {
        .LessEqual, .LessThan, .GreaterThan, .GreaterEqual, .NotEqual, .DoubleEqual => {
            const _comparation = src.next();

            const right = parse_primary_expr(self, src);

            const node = Node.new(
				.ComparationExpression,
				.{
					.left = left,
					.operator = operator,
					.right = right,
				},
            );
			node.span = _comparation.span;

			return node;
        },
        else => left,
    };
}

fn parse_additive_expr(self: Self, src: *Lexer) *Node {
    var left = parse_multiplicitave_expr(self, src);

    var operator = src.curr().?.tag;

    while (operator == .Plus or operator == .Minus) {
        const _expr = src.next();

        const right = parse_multiplicitave_expr(self, src);

        left = Node.new(
			.BinaryExpression,
            .{
                .left = left,
                .operator = operator,
                .right = right,
            },
        );
		left.span = _expr.span;

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_multiplicitave_expr(self: Self, src: *Lexer) *Node {
    var left = parse_primary_expr(self, src);

    var operator = src.curr().?.tag;

    while (
		operator == .Slash or
        operator == .Asterisk or
        operator == .Percent
	) {
        const _expr = src.next();

        const right = parse_primary_expr(self, src);

        left = Node.new(
			.BinaryExpression,
            .{
				.left = left,
				.operator = operator,
				.right = right,
			}
		);
		left.span = _expr.span;

        operator = src.curr().?.tag;
    }

    return left;
}

inline fn parse_num_expr(_: Self, src: *Lexer) *Node {
    const _number = src.next();

    const node = Node.new(
        .Number,
        .{
			.value = src.curr().?.value.?.number,
        },
    );
	node.span = _number.span;

	return node;
}

inline fn parse_id(self: Self, src: *Lexer) *Node {
    const _id = src.next();
	const next_node = src.peek();

	if(
		next_node != null and
		(
			next_node.?.tag == .Dot or
			next_node.?.tag == .Colon
		)
	) {
		return parse_member_access_expr(self, src);
	}

    return self.make_node(
		.Identifier,
        .{
			.name = src.curr().?.value.?.string,
        },
    );
}

inline fn parse_paren(self: Self, src: *Lexer) *Node {
    _ = src.next();

    const value = self.parse_expr(src);

    self.expect(.RightParen);
    _ = src.next();

    return value;
}

fn parse_primary_expr(self: Self, src: *Lexer) *Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Id => parse_identifier(self, src),
        .Str => parse_string_expr(self, src),
        .Num => parse_number_expr(self, src),
        .LeftParen => parse_paren(self, src),
        else => NeoError.throw(.{
            .err = .SyntaxError,
            .meta = .{ .character = @tagName(current.tag) },
			.span = current.span,
        }),
    };
}
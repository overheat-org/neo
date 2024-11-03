const std = @import("std");
const Lexer = @import("./lexer.zig");
const Token = @import("./token.zig");
const TokenTag = Token.Tag;

const _ast = @import("./ast.zig");
const Node = _ast.Node;
const AssignmentExpression = _ast.AssignmentExpression;
const BinaryExpression = _ast.BinaryExpression;

const allocator = std.heap.page_allocator;
const Self = @This();

pub const Errors = Lexer.Errors || std.mem.Allocator.Error || error{UnknownToken};

const Reader = struct {
    offset: usize,
    tokens: *std.ArrayList(Token),

    fn init(tokens: *std.ArrayList(Token)) Lexer.Errors!Reader {
        return Reader{
            .offset = 0,
            .tokens = tokens,
        };
    }

    fn curr(self: Reader) ?Token {
        if (self.offset >= self.tokens.items.len) {
            return null;
        }

        return self.tokens.items[self.offset];
    }

    fn peek(self: Reader) ?Token {
        if (self.offset + 1 >= self.tokens.items.len) {
            return null;
        }

        return self.tokens.items[self.offset + 1];
    }

    fn next(self: *Reader) Token {
        if (self.offset + 1 >= self.tokens.items.len) {
            return self.tokens.items[self.offset]; // Returing EOF
        }

        self.offset += 1;

        return self.tokens.items[self.offset];
    }
};

pub fn init(source: []const u8) Errors!Node {
    var tokens = try Lexer.init(source);
    defer tokens.deinit();

    var src = try Reader.init(&tokens);

    var program_children = std.ArrayList(*const Node).init(allocator);
    defer program_children.deinit();

    while (if (src.curr()) |c| c.tag != TokenTag.EOF else false) {
        const stmt = try parse_stmt(&src);

        try program_children.append(stmt);
    }

    const node = Node{
        .kind = .Program,
        .children = try program_children.toOwnedSlice(),
        .props = null,
    };

    return node;
}

fn parse_stmt(src: *Reader) Errors!*Node {
    return switch (src.curr().?.tag) {
        // .Var, .Const => {},

        else => try parse_expr(src),
    };
}

fn parse_expr(src: *Reader) Errors!*Node {
    return try parse_comparation_expr(src);
}

fn parse_comparation_expr(src: *Reader) Errors!*Node {
    const left = try parse_additive_expr(src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    const node = try allocator.create(Node);

    return switch (operator) {
        .Equal => {
            _ = src.next();

            const right = try parse_primary_expr(src);

            node.* = Node{
                .kind = .AssignmentExpression,
                .props = .{
                    .AssignmentExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
            };

            return node;
        },
        .LessEqual, .LessThan, .GreaterThan, .GreaterEqual, .NotEqual, .DoubleEqual => {
            _ = src.next();

            const right = try parse_primary_expr(src);

            node.* = Node{
                .kind = .ComparationExpression,
                .props = .{
                    .ComparationExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
            };

            return node;
        },
        else => left,
    };
}

fn parse_additive_expr(src: *Reader) Errors!*Node {
    var left = try parse_multiplicitave_expr(src);

    var operator = src.curr().?.tag;

    while (operator == .Plus or operator == .Minus) {
        _ = src.next();

        const right = try parse_multiplicitave_expr(src);

        const binary_expr = try allocator.create(Node);
        binary_expr.* = Node{
            .kind = .BinaryExpression,
            .props = .{
                .BinaryExpression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
        };

        left = binary_expr;

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_multiplicitave_expr(src: *Reader) Errors!*Node {
    var left = try parse_primary_expr(src);

    var operator = src.curr().?.tag;

    while (operator == .Slash or
        operator == .Asterisk or
        operator == .Percent)
    {
        _ = src.next();

        const right = try parse_primary_expr(src);

        const binary_expr = try allocator.create(Node);
        binary_expr.* = Node{
            .kind = .BinaryExpression,
            .props = .{
                .BinaryExpression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
        };

        left = binary_expr;

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_primary_expr(src: *Reader) Errors!*Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Identifier => {
            _ = src.next();

            const node = try allocator.create(Node);
            node.* = Node{
                .kind = .Identifier,
                .props = .{
                    .Identifier = .{
                        .name = current.value.?.string,
                    },
                },
            };

            return node;
        },
        .Number => {
            _ = src.next();

            const node = try allocator.create(Node);
            node.* = Node{
                .kind = .Number,
                .props = .{
                    .Number = .{
                        .value = current.value.?.number,
                    },
                },
            };

            return node;
        },
        .LeftParen => {
            _ = src.next();

            const value = try parse_expr(src);

            if (src.curr().?.tag != .RightParen) {
                @panic("Error");
            }

            _ = src.next();

            return value;
        },
        else => @panic("Unknown Token"),
    };
}

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
        self.offset += 1;

        return self.tokens.swapRemove(self.offset);
    }
};

pub fn init(source: []const u8) Errors!Node {
    var tokens = try Lexer.init(source);
    defer tokens.deinit();

    var src = try Reader.init(&tokens);

    var ProgramChildren = std.ArrayList(*const Node).init(allocator);
    errdefer ProgramChildren.deinit();

    while (if (src.curr()) |c| c.tag != TokenTag.EOF else false) {
        const stmt = &parse_stmt(&src);

        try ProgramChildren.append(stmt);
    }

    var AST = Node.init(.Program);
    AST.children = try ProgramChildren.toOwnedSlice();

    return AST;
}

fn parse_stmt(src: *Reader) Node {
    return switch (src.curr().?.tag) {
        // .Var, .Const => {},

        else => parse_expr(src),
    };
}

fn parse_expr(src: *Reader) Node {
    return parse_assign_expr(src);
}

fn parse_assign_expr(src: *Reader) Node {
    var left = parse_primary_expr(src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    return switch (operator) {
        .Equal, .PlusEqual, .MinusEqual, .AsteriskEqual, .SlashEqual, .PercentEqual => {
            _ = src.next();

            var right = parse_primary_expr(src);

            var node = Node.init(.AssignmentExpression);

            node.props = .{
                .AssignmentExpression = .{
                    .left = &left,
                    .operator = TokenTag.toString(operator),
                    .right = &right,
                },
            };

            return node;
        },

        else => left,
    };
}

fn parse_additive_expr(src: *Reader) Node {
    var left = parse_additive_expr(src);
    const operator = src.curr().?.tag;

    while (operator == .Plus or operator == .Minus) {
        _ = src.next();

        var right = parse_additive_expr(src);

        var binary = Node.init(.BinaryExpr);
        binary.props = .{
            .BinaryExpression = .{
                .left = &left,
                .operator = TokenTag.toString(operator),
                .right = &right,
            },
        };

        left = binary;
    }

    return left;
}

fn parse_multiplicitave_expr(src: *Reader) Node {
    var left = parse_additive_expr(src);
    const operator = src.curr().?.tag;

    while (operator == .Slash or
        operator == .Star or
        operator == .Percent)
    {
        _ = src.next();

        const right = parse_additive_expr(src);

        const binary = Node.init(.BinaryExpr);
        binary.props = .{
            .BinaryExpression = .{
                .left = &left,
                .operator = TokenTag.toString(operator),
                .right = &right,
            },
        };

        left = binary;
    }

    return left;
}

fn parse_primary_expr(src: *Reader) Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Identifier => {
            _ = src.next();

            var node = Node.init(.Identifier);
            node.props = .{ .Identifier = .{ .name = current.value.?.string } };

            return node;
        },
        .Number => {
            _ = src.next();

            var node = Node.init(.Number);
            node.props = .{ .Number = .{ .value = current.value.?.number } };

            return node;
        },
        .LeftParen => {
            _ = src.next();

            const value = parse_expr(src);

            if (src.curr().?.tag != .RightParen) {
                @panic("Error");
            }

            _ = src.next();

            return value;
        },
        else => {
            std.debug.print("{any}", .{src.curr()});
            @panic("Unknown Token");
        },
    };
}

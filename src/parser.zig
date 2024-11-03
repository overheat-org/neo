const std = @import("std");
const Lexer = @import("./lexer.zig");
const Token = @import("./token.zig");
const TokenTag = Token.Tag;
const _ast = @import("./ast.zig");
const Node = _ast.Node;
const AssignmentExpression = _ast.AssignmentExpression;
const BinaryExpression = _ast.BinaryExpression;
const Ast = @import("./ast.zig");

const allocator = std.heap.page_allocator;

const Self = @This();

pub const Errors = Lexer.Errors || std.mem.Allocator.Error || error{UnknownToken};

const Reader = struct {
    offset: usize,
    tokens: *std.ArrayList(Token),

    fn init(tokens: *std.ArrayList(Token)) std.mem.Allocator.Error!*Reader {
        const reader = try allocator.create(Reader);
        reader.* = Reader{
            .offset = 0,
            .tokens = tokens,
        };

        return reader;
    }

    fn deinit(self: *Reader) void {
        allocator.free(self);
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

    inline fn expect(self: *Reader, comptime tags: *[]Token.Tag, comptime string: []const u8) !void {
        const token = self.curr().?;
        if (std.mem.indexOf(Token.Tag, tags, token.tag) == null) {
            @panic(string);
        }
    }

    inline fn not_eof(self: *Reader) bool {
        return if (self.curr()) |c| c.tag != TokenTag.EOF else false;
    }
};

result: Node = undefined,

pub fn init(source: []const u8) Errors!Self {
    Ast.node_ptrs_list = std.ArrayList(*const Node).init(allocator);

    var tokens = try Lexer.init(source);
    defer tokens.deinit();

    const src = try Reader.init(&tokens);
    defer src.deinit();

    var program_children = std.ArrayList(*const Node).init(allocator);
    defer program_children.deinit();

    while (src.not_eof()) {
        const stmt = try parse_stmt(src);

        try program_children.append(stmt);
    }

    return Self{
        .result = Node{
            .kind = .Program,
            .children = try program_children.toOwnedSlice(),
            .props = null,
        },
    };
}

pub fn deinit() void {
    for (Ast.node_ptrs_list.items) |item| {
        allocator.free(item);
    }

    Ast.node_ptrs_list.deinit();
}

fn parse_stmt(src: *Reader) Errors!*Node {
    return switch (src.curr().?.tag) {
        .Var, .Const => parse_var_decl(src),

        else => try parse_expr(src),
    };
}

fn parse_var_decl(src: *Reader) Errors!*Node {
    const keyword = src.next();
    const is_const = keyword.tag == .Const;

    const identifierNode = try parse_primary_expr(src);
    const token = try src.expect(&[_]Token.Tag{ .Equal, .SemiColon }, "Expecting semi-colon or equal");

    return Node.init(.{
        .kind = .VarDeclaration,
        .props = .{
            .VarDeclaration = .{
                .id = identifierNode,
                .value = if (token.tag == .Equal) try parse_expr(src) else &Node{ .kind = .Null },
                .constant = is_const,
            },
        },
    });
}

fn parse_expr(src: *Reader) Errors!*Node {
    return try parse_object_expr(src);
}

fn parse_object_expr(src: *Reader) Errors!*Node {
    if (src.curr().?.tag != .LeftBrace) return parse_comparation_expr(src);

    _ = src.next();

    const props = std.AutoHashMap(Node, Node).init(allocator);

    while (src.not_eof() and src.curr().?.tag != .RightBrace) {
        try src.expect(.{.Identifier}, "Object literal key expected");
        const key = try parse_primary_expr(src);

        try src.expect(.{.Equal}, "Missing colon following Identifier in Object Expression");
        const value = try parse_expr(src);

        try props.put(key, value);
    }
}

fn parse_comparation_expr(src: *Reader) Errors!*Node {
    const left = try parse_additive_expr(src);
    const operator: Token.Tag = if (src.curr()) |c| c.tag else .EOF;

    return switch (operator) {
        .Equal => {
            _ = src.next();

            const right = try parse_primary_expr(src);

            return Node.init(.{
                .kind = .AssignmentExpression,
                .props = .{
                    .AssignmentExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
            });
        },
        .DoubleEqual => {
            _ = src.next();

            const right = try parse_primary_expr(src);

            return Node.init(.{
                .kind = .ComparationExpression,
                .props = .{
                    .ComparationExpression = .{
                        .left = left,
                        .operator = operator,
                        .right = right,
                    },
                },
            });
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

        left = Node.init(.{
            .kind = .BinaryExpression,
            .props = .{
                .BinaryExpression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
        });

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

        left = Node.init(.{
            .kind = .BinaryExpression,
            .props = .{
                .BinaryExpression = .{
                    .left = left,
                    .operator = operator,
                    .right = right,
                },
            },
        });

        operator = src.curr().?.tag;
    }

    return left;
}

fn parse_primary_expr(src: *Reader) Errors!*Node {
    const current = src.curr().?;

    return switch (current.tag) {
        .Identifier => {
            _ = src.next();

            return Node.init(.{
                .kind = .Identifier,
                .props = .{
                    .Identifier = .{
                        .name = current.value.?.string,
                    },
                },
            });
        },
        .Number => {
            _ = src.next();

            return Node.init(.{
                .kind = .Number,
                .props = .{
                    .Number = .{
                        .value = current.value.?.number,
                    },
                },
            });
        },
        .LeftParen => {
            _ = src.next();

            const value = try parse_expr(src);

            _ = try src.expect(.{.RightParen}, "Expecting \")\"");
            _ = src.next();

            return value;
        },
        else => Errors.UnknownToken,
    };
}

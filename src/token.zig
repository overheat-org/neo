const std = @import("std");

const allocator = std.heap.page_allocator;

pub const Tag = enum {
    Null,
    Identifier,
    Number,
    String,
    Boolean,
    Equal,
    Var,
    Const,
    If,
    Else,
    Fn,
    While,
    For,
    DoubleEqual,
    NotEqual,
    GreaterThan,
    GreaterEqual,
    LessThan,
    LessEqual,
    Exclamation,
    Dot,
    SemiColon,
    Colon,
    Plus,
    Minus,
    Asterisk,
    Slash,
    Percent,
    Decorator,
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    EOF,
};

pub const Value = union {
    string: []const u8,
    number: f64,
};

pub const Span = struct {
    line: usize,
    column: usize,
};

const Self = @This();

tag: Tag,
value: ?Value,
span: Span,

pub const keywords = std.StaticStringMap(Tag).initComptime(.{
    .{ "var", Tag.Var },
    .{ "const", Tag.Const },
    .{ "if", Tag.If },
    .{ "else", Tag.Else },
    .{ "while", Tag.While },
    .{ "for", Tag.For },
});

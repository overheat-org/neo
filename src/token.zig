pub const Tag = enum {
    Null,
    Identifier,
    Keyword,
    Number,
    String,
    Equal,
    DoubleEqual,
    NotEqual,
    GreaterThan,
    GreaterEqual,
    LessThan,
    LessEqual,
    Exclamation,
    Dot,
    Colon,
    Plus,
    Minus,
    Asterisk,
    Slash,
    Percent,
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

const Self = @This();

tag: Tag,
value: ?Value,

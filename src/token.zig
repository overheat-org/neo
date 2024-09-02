pub const Tag = enum {
    Identifier,
    Keyword,
    Number,
    String,
    Equal,
    DoubleEqual,
    NotEqual,
    PlusEqual,
    MinusEqual,
    AsteriskEqual,
    SlashEqual,
    PercentEqual,
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

    pub fn toString(tag: Tag) []const u8 {
        return switch (tag) {
            .Equal => "=",
            .DoubleEqual => "==",
            .NotEqual => "!=",
            .PlusEqual => "+=",
            .MinusEqual => "-=",
            .AsteriskEqual => "*=",
            .SlashEqual => "/=",
            .PercentEqual => "%=",
            else => "\x00",
        };
    }
};

pub const Value = union {
    string: []const u8,
    number: f64,
};

const Self = @This();

tag: Tag,
value: ?Value,

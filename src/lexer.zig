const std = @import("std");
const Token = @import("./token.zig");

const NULL_CHAR = '\x00';
const allocator = std.heap.page_allocator;

pub const Errors = error{
    UnknownCharacter,
    InvalidCharacter,
    OutOfMemory,
};

const Reader = struct {
    offset: usize,
    line_pos: usize,
    column_pos: usize,
    content: []const u8,

    fn init(content: []const u8) Reader {
        return Reader{
            .offset = 0,
            .line_pos = 1,
            .column_pos = 1,
            .content = content,
        };
    }

    inline fn curr(self: Reader) u8 {
        if (self.offset < self.content.len) {
            return self.content[self.offset];
        }

        return NULL_CHAR;
    }

    inline fn next(self: *Reader) u8 {
        self.offset += 1;
        self.column_pos += 1;

        return self.curr();
    }

    inline fn peek(self: Reader) u8 {
        if (self.offset + 1 < self.content.len) {
            return self.content[self.offset + 1];
        }

        return NULL_CHAR;
    }

    inline fn break_line(self: *Reader) void {
        self.offset += 1;
        self.line_pos += 1;
    }
};

const Tokens = struct {
    value: std.ArrayList(Token),

    inline fn init() Tokens {
        return Tokens{
            .value = std.ArrayList(Token).init(allocator),
        };
    }

    fn save(self: *Tokens, tag: Token.Tag, value: ?Token.Value) void {
        self.value.append(Token{ .tag = tag, .value = value }) catch @panic("Can't save token on Lexer");
    }
};

pub fn init(source: []const u8) Errors!std.ArrayList(Token) {
    var src = Reader.init(source);
    var tokens = Tokens.init();

    while (src.offset < src.content.len) {
        const curr = src.curr();

        switch (curr) {
            // zig fmt: off
            ' ', '\t', '\r' => _ = src.next(),
            '\n' => src.break_line(),
            '=' => {
                if (src.peek() == '=') {
                    tokens.save(.DoubleEqual, null);
                    _ = src.next();
                } else {
                    tokens.save(.Equal, null);
                }
                _ = src.next();
            },
            '!' => {
                if (src.peek() == '=') {
                    tokens.save(.NotEqual, null);
                    _ = src.next();
                } else {
                    tokens.save(.Exclamation, null);
                }
                _ = src.next();
            },
            '>' => {
                if (src.peek() == '=') {
                    tokens.save(.GreaterEqual, null);
                    _ = src.next();
                } else {
                    tokens.save(.GreaterThan, null);
                }
                _ = src.next();
            },
            '<' => {
                if (src.peek() == '=') {
                    tokens.save(.LessEqual, null);
                    _ = src.next();
                } else {
                    tokens.save(.LessThan, null);
                }
                _ = src.next();
            },
            '.' => {
                tokens.save(.Dot, null);
                _ = src.next();
            },
            ':' => {
                tokens.save(.Colon, null);
                _ = src.next();
            },
            '+' => {
                tokens.save(.Plus, null);
                _ = src.next();
            },
            '-' => {
                tokens.save(.Minus, null);
                _ = src.next();
            },
            '*' => {
                tokens.save(.Asterisk, null);
                _ = src.next();
            },
            '/' => {
                tokens.save(.Slash, null);
                _ = src.next();
            },
            '%' => {
                tokens.save(.Percent, null);
                _ = src.next();
            },
            '@' => {
                tokens.save(.Decorator, null);
                _ = src.next();
            },
            '(' => {
                tokens.save(.LeftParen, null);
                _ = src.next();
            },
            ')' => {
                tokens.save(.RightParen, null);
                _ = src.next();
            },
            '{' => {
                tokens.save(.LeftBrace, null);
                _ = src.next();
            },
            '}' => {
                tokens.save(.RightBrace, null);
                _ = src.next();
            },
            '[' => {
                tokens.save(.LeftBracket, null);
                _ = src.next();
            },
            ']' => {
                tokens.save(.RightBracket, null);
                _ = src.next();
            },
            '\'', '"' => {
                const str = makeString(curr, &src);
                const value = Token.Value{ .string = str };

                tokens.save(.String, value);
            },
            'a'...'z', 'A'...'Z' => {
                const text = makeText(&src).string;

                if(Token.keywords.has(text)) {
                    tokens.save(Token.keywords.get(text).?, null);
                }
                else {
                    tokens.save(.Identifier, .{ .string = text });
                }
            },
            '0' => tokens.save(.Number,
                // if (source.peek() == 'x')
                //     makeHexa(&source)
                // else if (source.peek() == 'b')
                //     makeBinary(&source)
                // else 
                    try makeNumber(&src)
            ),
            '1'...'9' => tokens.save(.Number, try makeNumber(&src)),
            else => return Errors.UnknownCharacter,
            // zig fmt: on
        }
    }

    tokens.save(.EOF, null);

    return tokens.value;
}

fn makeText(source: *Reader) Token.Value {
    const start_offset = source.offset;

    while (isLetter(source.peek()) or isNumber(source.peek()) or source.peek() == '_') {
        _ = source.next();
    }

    _ = source.next();

    const end_offset = source.offset;

    const identifier = source.content[start_offset..end_offset];

    return Token.Value{ .string = identifier };
}

fn makeNumber(source: *Reader) std.fmt.ParseFloatError!Token.Value {
    const start_offset = source.offset;

    while (isNumber(source.peek())) {
        _ = source.next();
    }

    _ = source.next();

    const end_offset = if (start_offset == source.offset) source.offset + 1 else source.offset;

    const number = try std.fmt.parseFloat(f64, source.content[start_offset..end_offset]);

    return Token.Value{ .number = number };
}

fn makeString(char: u8, source: *Reader) []const u8 {
    _ = source.next();

    const start_offset = source.offset;

    while (source.curr() != char) {
        _ = source.next();
    }

    const end_offset = source.offset;

    _ = source.next();

    return source.content[start_offset..end_offset];
}

// fn makeHexa(source: *Source) f64 {}

// fn makeBinary(source: *Source) f64 {}

fn isNumber(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn isLetter(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z');
}

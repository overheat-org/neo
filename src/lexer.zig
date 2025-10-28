const std = @import("std");
const Token = @import("./token.zig");
const Span = Token.Span;
const VesperError = @import("./reporter.zig");

const NULL_CHAR = '\x00';
const allocator = std.heap.page_allocator;

const Self = @This();

source: []const u8,
offset: usize = 0,
line: usize = 1,
column: usize = 1,
current: ?Token,

inline fn is_number(char: u8) bool {
    return char >= '0' and char <= '9';
}

inline fn is_letter(char: u8) bool {
    return (char >= 'a' and char <= 'z') or (char >= 'A' and char <= 'Z');
}

pub fn init(source: []const u8) Self {
	return Self{
		.source = source,
	};
}

pub fn next(self: *Self) Token {
	const source = self.source;
	const offset = self.offset;
	const make_token = self.create_token;
	
	self.walk();
	
	const token = switch (source[offset]) {
		' ', '\t', '\r' => self.next(),
		'\n' => {
			self.offset += 1;
			self.line += 1;

			return self.next();
		},
		'=' => {
			if (self.peek() == '=') {
				self.walk();

				return make_token(.DoubleEqual, null);
			}
			
			return make_token(.Equal, null);
		},
		'!' => {
			if (self.peek() == '=') {
				self.walk();

				return make_token(.NotEqual, null);
			}

			return make_token(.Exclamation, null);
		},
		'>' => {
			if (self.peek() == '=') {
				self.walk();

				return make_token(.GreaterEqual, null);
			}

			return make_token(.GreaterThan, null);
		},
		'<' => {
			if (self.peek() == '=') {
				self.walk();

				return make_token(.LessEqual, null);
			}

			return make_token(.LessThan, null);
		},
		'.' => {
			return make_token(.Dot, null);
		},
		':' => {
			return make_token(.Colon, null);
		},
		'+' => {
			return make_token(.Plus, null);
		},
		'-' => {
			return make_token(.Minus, null);
		},
		'*' => {
			return make_token(.Asterisk, null);
		},
		'/' => {
			return make_token(.Slash, null);
		},
		'%' => {
			return make_token(.Percent, null);
		},
		'@' => {
			return make_token(.Decorator, null);
		},
		'(' => {
			return make_token(.LeftParen, null);
		},
		')' => {
			return make_token(.RightParen, null);
		},
		'{' => {
			return make_token(.LeftBrace, null);
		},
		'}' => {
			return make_token(.RightBrace, null);
		},
		'[' => {
			return make_token(.LeftBracket, null);
		},
		']' => {
			return make_token(.RightBracket, null);
		},
		'\'', '"' => {
			return make_token(
				.String,
				.{ .string = make_string(curr, &src) }
			);
		},
		'a'...'z', 'A'...'Z' => {
			const value = make_text(&src);

			if (Token.keywords.has(value.string)) {
				return make_token(Token.keywords.get(value.string), null);
			} else {
				return make_token(.Identifier, value);
			}
		},
		'0' => make_token(
			.Number,
			switch (self.peek()) {
				'x' => make_hexa(&src),
				'b' => make_binary(&src),
				_ 	=> make_number(&src),
			}
		),
		'1'...'9' => make_token(.Number, make_number(&src)),
		else => unreachable,
	};



	return token;
}

fn create_token(self: *Self, tag: Token.Tag, value: ?Token.Value) Token {
	return Token{
		.tag = tag,
		.value = value,
		.span = Span{
			.line = self.line,
			.column = self.column,
		},
	};
}

fn walk(self: *Self) void {
	self.offset += 1;
	self.column += 1;
}

fn peek(self: *Self) u8 {
	if (self.offset >= self.source.len) {
		return NULL_CHAR;
	}
	return self.source[self.offset];
}

fn make_text(source: *Reader) Token.Value {
    const start_offset = source.offset;

    while (is_letter(source.peek()) or is_number(source.peek()) or source.peek() == '_') {
        _ = source.next();
    }

    _ = source.next();

    const end_offset = source.offset;

    const identifier = source.content[start_offset..end_offset];

    return Token.Value{ .string = identifier };
}

fn make_number(source: *Reader) Token.Value {
    const start_offset = source.offset;

    while (is_number(source.peek())) {
        _ = source.next();
    }

    _ = source.next();

    const end_offset = if (start_offset == source.offset) source.offset + 1 else source.offset;
    const slice = source.content[start_offset..end_offset];

    const number = std.fmt.parseFloat(f64, slice) 
        catch VesperError.throw(.{ .err = .TypeMismatch, .meta = .{ .expected = "number", .found = slice } });

    return Token.Value{ .number = number };
}

fn make_string(char: u8, source: *Reader) []const u8 {
    _ = source.next();

    const start_offset = source.offset;

    while (source.curr() != char) {
        _ = source.next();
    }

    const end_offset = source.offset;

    _ = source.next();

    return source.content[start_offset..end_offset];
}

fn make_hexa(source: *Source) f64 {}

fn make_binary(source: *Source) f64 {}

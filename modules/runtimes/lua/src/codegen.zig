const std = @import("std");
const neo = @import("neo");
const NeoError = neo.reporter;
const Node = neo.node;
const unwrap_error = neo.utils.unwrap_error;

const Codegen = @This();

buffer: std.ArrayList(u8),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Codegen {
	return .{
		.allocator = allocator,
		.buffer = std.ArrayList(u8).init(allocator),
	};
}

pub fn deinit(self: *Codegen) void {
	self.buffer.deinit();
}

pub fn generate(self: *Codegen, ast: *Node) []u8 {
	self.traverse(ast);
	return unwrap_error(self.buffer.toOwnedSlice());
}

fn write(self: *Codegen, text: []const u8) void {
	unwrap_error(self.buffer.appendSlice(text));
}

fn traverse(self: *Codegen, node: *Node) void {
	defer node.destroy();

	switch (node.kind) {
		.Program => {
			for (node.children) |child| {
				traverse(self, child);
			}
		},
		.If => {
			const props = node.props.If;
			
			self.write("if ");
			traverse(self, props.expect);
			self.write(" then ");
			traverse(self, props.then);

			var children = props.children;
			while (children) |child| {
				if (child.kind == .If) {
					self.write("\nelseif ");
					traverse(self, child);
				} else {
					self.write("\nelse ");
					traverse(self, child);
				}
				children = child.children;
			}

			self.write("\nend\n");
		},
		.BinaryExpression => {
			return node.repr();
		},
		.Block => { 
			self.write("do\n");
			for (node.children) |child| {
				traverse(self, child);
			}
			self.write("\nend\n");
		},
		.Number => {
			node.repr();
		},
		.String => {
			node.repr();
		},
		.Null => {
			self.write("nil");
		},
		else => unreachable,
	}
}

test {
	const ast = Node.new(.If, .{
		.expect = Node.new(.Number, .{ .value = 5 }),
		.then = Node.new(.Null, .{}),
		.children = Node.new(.If, .{
			.expect = Node.new(.Number, .{ .value = 5 }),
			.then = Node.new(.Null, .{}),
			.children = null
		})
	});

	const codegen = Codegen.init(std.testing.allocator);
	const code = codegen.generate(ast);
	
	std.debug.print(
		"{s}",
		.{code}
	);
}
const std = @import("std");
const neo = @import("neo");
const NeoError = neo.reporter;
const Node = neo.node;
const format = neo.utils.format;

const allocator = std.heap.page_allocator;

pub fn codegen(node: *Node, parent: ?*Node) []u8 {
	return switch (node.kind) {
		.Program => {
			const a = [10].{};
			
			for (node.children) |child| {
				child;codegen(node.children[0], null)
			}
		},
        .If => {
            const props = node.props.If;
            const expect = codegen(props.expect, null);
            const then = codegen(props.then, null);
            
            const children = if (props.children) |child| blk: {
                if (child.kind == .If) {
                    break :blk format("{s} end", .{codegen(child, node)});
                }
                break :blk format("{s} end", .{codegen(child, null)});
            } else "end";
            
            return if (parent == null or parent.?.kind != .If)
                format("if {s} then {s} {s}", .{ expect, then, children })
            else
                format("elseif {s} then {s} {s}", .{ expect, then, children });
        },
		.BinaryExpression => node.repr(),
		.Block => format("do {s} end", .{"TODO"}),
		.Number => node.repr(),
		.String => node.repr(),
		.Null => format("nil", .{}),
		else => unreachable,
	};
}

test {
	const code = codegen(Node.new(.If, .{
		.expect = Node.new(.Number, .{ .value = 5 }),
		.then = Node.new(.Null, .{}),
		.children = Node.new(.If, .{
			.expect = Node.new(.Number, .{ .value = 5 }),
			.then = Node.new(.Null, .{}),
			.children = null
		})
	}), null);
	
	std.debug.print(
		"{s}",
		.{code}
	);
}
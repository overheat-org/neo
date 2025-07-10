const std = @import("std");
const NeoError = @import("./reporter.zig");
const Node = @import("./node.zig");

const Allocator = std.mem.Allocator;

pub fn ArrayListWrapper(comptime T: type) type {
	const arrayList = std.ArrayList(T);

	return struct {
        const Self = @This();

		_base_: arrayList,

		pub const Slice = arrayList.Slice;

		pub fn init(allocator: Allocator) Self {
            return Self{
                ._base_ = arrayList.init(allocator),
            };
        }

		pub fn append(self: *Self, item: T) void {
			unwrap_error(self._base_.append(item));
		}

		pub fn toOwnedSlice(self: *Self) Slice {
			unwrap_error(self._base_.toOwnedSlice());
		}
	};
}

pub const NodeMap = struct {
	const K = *Node;
	const V = *Node;
	const map = std.AutoHashMap(K, V);

	_base_: map,
	
	pub fn init(allocator: Allocator) NodeMap {
		return NodeMap{
			._base_ = map.init(allocator),
		};
	}

	pub fn put(self: *NodeMap, key: K, value: V) void {
		unwrap_error(self._base_.put(key, value));
	}
};

pub const AllocatorWrapper = struct {

};

pub fn unwrap_error(arg: anytype) @typeInfo(@TypeOf(arg)).error_union.payload {
	return arg catch |err| switch (err) {
		std.mem.Allocator.Error.OutOfMemory => NeoError.throw(.{
			.err = .OutOfMemory
		})
	};
}
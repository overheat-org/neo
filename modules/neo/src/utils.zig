const std = @import("std");
const NeoError = @import("./reporter.zig");
const Node = @import("./node.zig");

const Allocator = std.mem.Allocator;

/// An array with neo errors instead native errors
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

    __proto__: map,

    pub fn init(allocator: Allocator) NodeMap {
        return NodeMap{
            .__proto__ = map.init(allocator),
        };
    }

    pub fn put(self: *NodeMap, key: K, value: V) void {
        unwrap_error(self.__proto__.put(key, value));
    }
};

pub const AllocatorWrapper = struct {
    const Self = @This();
    const proto = std.heap.page_allocator;

    __proto__: Allocator,

    pub inline fn rawFree(self: Self, memory: []u8, alignment: Alignment, ret_addr: usize) void {
        return unwrap_error(self.rawFree(memory, alignment, ret_addr));
    }

    pub fn create(self: Self, comptime T: type) *T {
        return unwrap_error(self.__proto__.create(T));
    }

    pub fn destroy(self: Self, ptr: anytype) void {
        return unwrap_error(self.__proto__.destroy(ptr));
    }

    pub fn alloc(self: Self, comptime T: type, n: usize) []T {
        unwrap_error(self.__proto__.alloc(T, n));
    }

    pub fn allocWithOptions(
        self: Self,
        comptime Elem: type,
        n: usize,
        /// null means naturally aligned
        comptime optional_alignment: ?u29,
        comptime optional_sentinel: ?Elem,
    ) AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
        return unwrap_error(self.__proto__.allocWithOptions(Elem, n, optional_alignment, optional_sentinel));
    }

    pub fn allocWithOptionsRetAddr(
        self: Self,
        comptime Elem: type,
        n: usize,
        /// null means naturally aligned
        comptime optional_alignment: ?u29,
        comptime optional_sentinel: ?Elem,
        return_address: usize,
    ) AllocWithOptionsPayload(Elem, optional_alignment, optional_sentinel) {
        return unwrap_error(self.__proto__.allocWithOptionsRetAddr(Elem, n, optional_alignment, optional_sentinel, return_address));
    }

    pub fn allocSentinel(
        self: Self,
        comptime Elem: type,
        n: usize,
        comptime sentinel: Elem,
    ) [:sentinel]Elem {
        return unwrap_error(self.__proto__.allocSentinel(Elem, n, sentinel));
    }

    pub fn alignedAlloc(
        self: Self,
        comptime T: type,
        /// null means naturally aligned
        comptime alignment: ?u29,
        n: usize,
    ) []align(alignment orelse @alignOf(T)) T {
        return unwrap_error(self.__proto__.alignedAlloc(T, alignment, n));
    }

    pub inline fn allocAdvancedWithRetAddr(
        self: Self,
        comptime T: type,
        /// null means naturally aligned
        comptime alignment: ?u29,
        n: usize,
        return_address: usize,
    ) []align(alignment orelse @alignOf(T)) T {
        return unwrap_error(self.__proto__.allocAdvancedWithRetAddr(T, alignment, n, return_address));
    }

    pub fn resize(self: Self, allocation: anytype, new_len: usize) bool {
        return unwrap_error(self.__proto__.resize(allocation, new_len));
    }

    pub fn remap(self: Self, allocation: anytype, new_len: usize) t: {
        const Slice = @typeInfo(@TypeOf(allocation)).pointer;
        break :t ?[]align(Slice.alignment) Slice.child;
    } {
        return unwrap_error(self.__proto__.remap(allocation, new_len));
    }

    pub fn realloc(self: Self, old_mem: anytype, new_n: usize) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
        break :t []align(Slice.alignment) Slice.child;
    } {
        return unwrap_error(self.__proto__.realloc(old_mem, new_n));
    }

    pub fn reallocAdvanced(
        self: Self,
        old_mem: anytype,
        new_n: usize,
        return_address: usize,
    ) t: {
        const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
        break :t []align(Slice.alignment) Slice.child;
    } {
        unwrap_error(self.__proto__.reallocAdvanced(old_mem, new_n, return_address));
    }

    pub fn free(self: Self, memory: anytype) void {
        unwrap_error(self.__proto__.free(memory));
    }

    pub fn dupe(allocator: Self, comptime T: type, m: []const T) []T {
        return unwrap_error(proto.dupe(allocator, T, m));
    }

    pub fn dupeZ(allocator: Self, comptime T: type, m: []const T) [:0]T {
        return unwrap_error(proto.dupeZ(allocator, m));
    }
};

fn unwrap_error(arg: anytype) @typeInfo(@TypeOf(arg)).error_union.payload {
    return arg catch |err| switch (err) {
        std.mem.Allocator.Error.OutOfMemory => NeoError.throw(.{ .err = .OutOfMemory }),
    };
}

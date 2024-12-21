const std = @import("std");
const _token = @import("./token.zig");
const Span = _token.Span;
const Allocator = std.mem.Allocator;

const Errors = enum {
    InternalError,
    SyntaxError,
    DivisionByZero,
    TypeMismatch,
    UnknownNode,
    UndefinedVariable,
    InvalidExpression,
    OutOfMemory,
};

var allocator: Allocator = undefined;

const VesperError = @This();

err: Errors,
span: Span,
meta: std.StaticStringMap([]const u8),

pub inline fn init(_allocator: Allocator) void {
    allocator = _allocator;
}

pub fn new(err: Errors, span: Span, meta: anytype) VesperError {
    const meta_info = @typeInfo(@TypeOf(meta)).Struct;
    const fields = meta_info.fields;

    const slice = allocator.alloc([2][]const u8, fields.len) catch unreachable;

    comptime var i = 0;
    inline for (fields) |field| {
        slice[i] = .{ field.name, @field(meta, field.name) };

        i += 1;
    }

    const _meta = std.StaticStringMap([]const u8).init(slice, allocator) catch unreachable;

    return VesperError{ .err = err, .span = span, .meta = _meta };
}

pub fn throw(e: anytype) noreturn {
    nosuspend VesperError._throw_(e) catch {};

    std.process.exit(1);
}

fn _throw_(err: anytype) !void {
    const meta = if(@hasField(@TypeOf(err), "meta")) err.meta else .{};
    
    const e = if (@TypeOf(err) != VesperError) VesperError.new(err.err, .{ .line = 0, .column = 0 }, meta) else err;

    const stdout = std.io.getStdOut().writer();

    // try stdout.print("Error in file '{s}' at line {d}, column {d}: ", .{
    //     e.span.file, e.span.line, e.span.column,
    // });

    switch (e.err) {
        .InternalError => {
            try stdout.print("Internal Error: '{s}'", .{e.meta.get("exception").?});
        },
        .SyntaxError => {
            try stdout.print("Syntax Error", .{});

            if (e.meta.has("expected")) {
                try stdout.print(": expected '{s}'", .{e.meta.get("expected").?});
            }
            if (e.meta.has("found")) {
                try stdout.print(", but found '{s}'", .{e.meta.get("found").?});
            }
        },
        .DivisionByZero => {
            try stdout.print("Division by Zero Error", .{});
        },
        .TypeMismatch => {
            try stdout.print("Type Mismatch Error", .{});

            if (e.meta.has("expected")) {
                try stdout.print(": expected type '{s}'", .{e.meta.get("expected").?});
            }
            if (e.meta.has("found")) {
                try stdout.print(", but found type '{s}'", .{e.meta.get("found").?});
            }
        },
        .OutOfMemory => {
            try stdout.print("Out of Memory", .{});
        },
        .UndefinedVariable => {
            try stdout.print("Undefined Variable Error", .{});

            if (e.meta.has("variable")) {
                try stdout.print(": variable '{s}' is not defined", .{e.meta.get("variable").?});
            }
        },
        .UnknownNode => {
            try stdout.print("Unknown Node: '{s}'", .{e.meta.get("node").?});
        },
        else => {
            try stdout.print("Unknown Error", .{});
        },
    }

    try stdout.print("\n", .{});
}

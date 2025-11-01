const std = @import("std");

// ============================================================================
// METHOD 1: Switch on a comptime type parameter
// ============================================================================
// Use this when you have a function parameter: comptime T: type

fn processType(comptime T: type) void {
    switch (T) {
        i32 => std.debug.print("Got i32\n", .{}),
        f64 => std.debug.print("Got f64\n", .{}),
        bool => std.debug.print("Got bool\n", .{}),
        []const u8 => std.debug.print("Got string slice\n", .{}),
        else => std.debug.print("Got unknown type: {s}\n", .{@typeName(T)}),
    }
}

// ============================================================================
// METHOD 2: Switch on @TypeOf() with anytype parameter
// ============================================================================
// Use this when you have: value: anytype

fn processValue(value: anytype) void {
    const T = @TypeOf(value);
    switch (T) {
        i32 => std.debug.print("Value is i32: {}\n", .{value}),
        f64 => std.debug.print("Value is f64: {}\n", .{value}),
        bool => std.debug.print("Value is bool: {}\n", .{value}),
        []const u8 => std.debug.print("Value is string: {s}\n", .{value}),
        else => std.debug.print("Value is unknown type: {s}\n", .{@typeName(T)}),
    }
}

// ============================================================================
// METHOD 3: Using @typeInfo() for more complex type introspection
// ============================================================================
// Use this when you need to check type categories or properties

fn analyzeType(comptime T: type) void {
    const type_info = @typeInfo(T);
    switch (type_info) {
        .Int => |info| {
            std.debug.print("Integer type: signed={}, bits={}\n", .{ info.signedness == .signed, info.bits });
        },
        .Float => |info| {
            std.debug.print("Float type: bits={}\n", .{info.bits});
        },
        .Pointer => |info| {
            std.debug.print("Pointer type: size={}, is_const={}\n", .{ @tagName(info.size), info.is_const });
        },
        .Array => |info| {
            std.debug.print("Array type: len={}, child={s}\n", .{ info.len, @typeName(info.child) });
        },
        .Struct => {
            std.debug.print("Struct type: {s}\n", .{@typeName(T)});
        },
        else => {
            std.debug.print("Other type: {}\n", .{@tagName(type_info)});
        },
    }
}

// ============================================================================
// METHOD 4: Combined approach - check type and extract value
// ============================================================================

fn convertValue(value: anytype) void {
    const T = @TypeOf(value);
    const result = switch (T) {
        i32 => blk: {
            const int_val: i32 = value;
            std.debug.print("Converting i32: {}\n", .{int_val});
            break :blk int_val * 2;
        },
        f64 => blk: {
            const float_val: f64 = value;
            std.debug.print("Converting f64: {}\n", .{float_val});
            break :blk float_val * 2.0;
        },
        []const u8 => blk: {
            const str_val: []const u8 = value;
            std.debug.print("Converting string: {s}\n", .{str_val});
            break :blk str_val.len;
        },
        else => |t| {
            @compileError("Unsupported type: " ++ @typeName(t));
        },
    };
    _ = result;
}

// ============================================================================
// METHOD 5: Type matching with specific types
// ============================================================================

fn handleSpecificTypes(comptime T: type) type {
    return switch (T) {
        i32, u32 => struct {
            pub fn double(x: T) T {
                return x * 2;
            }
        },
        f32, f64 => struct {
            pub fn double(x: T) T {
                return x * 2.0;
            }
        },
        else => @compileError("Type not supported"),
    };
}

// ============================================================================
// METHOD 6: Runtime type checking (when you need runtime behavior)
// ============================================================================
// Note: This is less common in Zig since most type checking is compile-time

fn processRuntimeType(value: anytype) void {
    const T = @TypeOf(value);

    // You can still use comptime switches for compile-time decisions
    // but return different runtime behaviors
    const handler = switch (T) {
        i32 => struct {
            fn handle(val: i32) void {
                std.debug.print("Handling i32: {}\n", .{val});
            }
        }.handle,
        f64 => struct {
            fn handle(val: f64) void {
                std.debug.print("Handling f64: {}\n", .{val});
            }
        }.handle,
        []const u8 => struct {
            fn handle(val: []const u8) void {
                std.debug.print("Handling string: {s}\n", .{val});
            }
        }.handle,
        else => struct {
            fn handle(_: anytype) void {
                std.debug.print("Handling unknown type\n", .{});
            }
        }.handle,
    };

    handler(value);
}

// ============================================================================
// TESTS
// ============================================================================

test "method 1: switch on comptime type" {
    processType(i32);
    processType(f64);
    processType(bool);
    processType([]const u8);
    processType(struct { x: i32 });
}

test "method 2: switch on anytype value" {
    processValue(@as(i32, 42));
    processValue(@as(f64, 3.14));
    processValue(true);
    processValue("hello");
}

test "method 3: type info introspection" {
    analyzeType(i32);
    analyzeType(u64);
    analyzeType(f64);
    analyzeType([]const u8);
    analyzeType([10]u8);
    analyzeType(struct { x: i32 });
}

test "method 4: convert value" {
    convertValue(@as(i32, 5));
    convertValue(@as(f64, 3.14));
    convertValue("hello");
}

test "method 5: type matching" {
    const IntOps = handleSpecificTypes(i32);
    const FloatOps = handleSpecificTypes(f64);

    try std.testing.expectEqual(@as(i32, 10), IntOps.double(5));
    try std.testing.expectEqual(@as(f64, 6.28), FloatOps.double(3.14));
}

test "method 6: runtime type handling" {
    processRuntimeType(@as(i32, 42));
    processRuntimeType(@as(f64, 3.14));
    processRuntimeType("hello");
}

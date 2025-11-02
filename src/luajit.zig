const std = @import("std");
const reflect = @import("reflectUtils");
const c = @cImport({
    @cInclude("luajit.h");
    @cInclude("lualib.h");
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
});
pub const LuaErrors = error{
    FailedToSetLuaJITMode,
    FailedToLoadFile,
    FailedToCallChunk,
    FailedToReadField,
    WrongInputType,
    FieldTypeNotImpleneted,
};

const Lua = struct {
    L: ?*c.struct_lua_State = null,
    pub fn init(self: *@This()) !void {
        self.L = c.lua_open();
        const ok = c.luaJIT_setmode(self.L, 0, c.LUAJIT_MODE_ENGINE | c.LUAJIT_MODE_ON);
        if (ok == 0) {
            return LuaErrors.FailedToSetLuaJITMode;
        }
        c.luaL_openlibs(self.L);
    }

    pub fn loadFile(self: *@This(), path: [*c]const u8) !void {
        if (c.luaL_loadfile(self.L, path) != 0) {
            const err = try self.readString();
            std.debug.print("{s}\n", .{err});
            return LuaErrors.FailedToLoadFile;
        }
        if (c.lua_pcall(self.L, 0, 0, 0) != 0) {
            const err = try self.readString();
            std.debug.print("{s}\n", .{err});
            return LuaErrors.FailedToCallChunk;
        }
    }

    pub fn readField(self: *Lua, comptime T: type, field: []const u8) !T {
        c.lua_getfield(self.L, -1, @ptrCast(field));
        defer _ = c.lua_pop(self.L, 1); // Clean up the stack after reading
        return try self.read(T);
    }

    pub fn read(self: *Lua, comptime T: type) !T {
        return switch (T) {
            // String types
            []const u8 => try self.readString(),
            [*c]const u8 => c.lua_tolstring(self.L, -1, null),
            *const [*c]const u8 => c.lua_tolstring(self.L, -1, null),

            // Boolean
            bool => c.lua_toboolean(self.L, -1) != 0,

            // Signed integers - convert from Lua number
            i8 => @as(i8, @intFromFloat(c.lua_tonumber(self.L, -1))),
            i16 => @as(i16, @intFromFloat(c.lua_tonumber(self.L, -1))),
            i32 => @as(i32, @intFromFloat(c.lua_tonumber(self.L, -1))),
            i64 => @as(i64, @intFromFloat(c.lua_tonumber(self.L, -1))),
            isize => @as(isize, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_int => @as(c_int, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_long => @as(c_long, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_longlong => @as(c_longlong, @intFromFloat(c.lua_tonumber(self.L, -1))),

            // Unsigned integers - convert from Lua number
            u8 => @as(u8, @intFromFloat(c.lua_tonumber(self.L, -1))),
            u16 => @as(u16, @intFromFloat(c.lua_tonumber(self.L, -1))),
            u32 => @as(u32, @intFromFloat(c.lua_tonumber(self.L, -1))),
            u64 => @as(u64, @intFromFloat(c.lua_tonumber(self.L, -1))),
            usize => @as(usize, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_uint => @as(c_uint, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_ulong => @as(c_ulong, @intFromFloat(c.lua_tonumber(self.L, -1))),
            c_ulonglong => @as(c_ulonglong, @intFromFloat(c.lua_tonumber(self.L, -1))),

            // Floating point types
            f32 => @as(f32, @floatCast(c.lua_tonumber(self.L, -1))),
            f64 => c.lua_tonumber(self.L, -1),

            // Pointer types
            ?*anyopaque => if (c.lua_isnil(self.L, -1) != 0) null else c.lua_touserdata(self.L, -1),
            *anyopaque => c.lua_touserdata(self.L, -1) orelse return LuaErrors.FailedToReadField,
            ?*c.struct_lua_State => if (c.lua_isnil(self.L, -1) != 0) null else c.lua_tothread(self.L, -1),
            *c.struct_lua_State => c.lua_tothread(self.L, -1) orelse return LuaErrors.FailedToReadField,
            ?*const anyopaque => if (c.lua_isnil(self.L, -1) != 0) null else @ptrCast(c.lua_topointer(self.L, -1)),
            *const anyopaque => @ptrCast(c.lua_topointer(self.L, -1) orelse return LuaErrors.FailedToReadField),
            c.lua_CFunction => c.lua_tocfunction(self.L, -1) orelse return LuaErrors.FailedToReadField,
            ?c.lua_CFunction => c.lua_tocfunction(self.L, -1),

            // Optional types - check for nil first
            else => switch (@typeInfo(T)) {
                .Optional => |optional_info| {
                    if (c.lua_isnil(self.L, -1) != 0) {
                        return null;
                    }
                    // Recursively call read with the inner type
                    return @as(T, try self.read(optional_info.child));
                },
                .Pointer => |ptr_info| {
                    // Handle generic pointer types
                    if (ptr_info.size == .one) {
                        if (c.lua_isnil(self.L, -1) != 0) {
                            return @as(T, @ptrFromInt(0));
                        }
                        return @as(T, @ptrCast(c.lua_touserdata(self.L, -1)));
                    }
                    @compileError("Unsupported pointer type: " ++ @typeName(T));
                },
                else => {
                    std.debug.print("Unsupported type: {s}\n", .{@typeName(T)});
                    return LuaErrors.FailedToReadField;
                },
            },
        };
    }

    fn readTable(self: *Lua, table: anytype) !void {
        const info = @typeInfo(@TypeOf(table));
        if (info != .pointer) {
            @compileError("table should be a pointer to a table");
        }
        if (@typeInfo(info.pointer.child) != .@"struct") {
            @compileError("pointee should be struct");
        }
        if (info.pointer.is_const) {
            @compileError("pointee should not be const");
        }
        const fields = comptime @typeInfo(info.pointer.child).@"struct".fields;

        inline for (fields) |f| {
            @field(table.*, f.name) = try self.readField(f.type, f.name);
        }
    }

    fn readString(self: *@This()) ![]const u8 {
        const len: [*c]usize = null;
        const c_str = c.lua_tolstring(self.L, -1, len);
        return std.mem.span(c_str);
    }
};

test "structural typing" {
    var l: Lua = .{};
    try l.init();
    try l.loadFile("./lua/global_table.lua");
    c.lua_getglobal(l.L, "T");
    const T = struct { c: usize = 0, e: f64 = 0.0 };
    var t: T = .{};
    try l.readTable(&t);
    try std.testing.expect(t.c == 77);
    try std.testing.expect(t.e == 7.7);
    std.debug.print("{any}\n", .{t});
}

test "read field value" {
    var l: Lua = .{};
    try l.init();
    try l.loadFile("./lua/global_table.lua");
    c.lua_getglobal(l.L, "T");
    const field_value = try l.readField([]const u8, "a");
    try std.testing.expectEqualStrings("this is 'a' field value", field_value);
}

test "lua loadFile" {
    var l: Lua = .{};
    try l.init();
    try l.loadFile("./lua/global_string.lua");
    c.lua_getglobal(l.L, "Message");
    const c_typename = c.luaL_typename(l.L, -1);
    const val = try l.readString();
    try std.testing.expectEqualStrings("string", std.mem.span(c_typename));
    try std.testing.expectEqualStrings("Hello From Lua", val);
}

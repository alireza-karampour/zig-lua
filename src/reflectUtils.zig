const std = @import("std");
const t = std.testing;
pub fn fieldNames(comptime T: type) []const []const u8 {
    const st = @typeInfo(T);
    const len = st.@"struct".fields.len;
    comptime var fields: [len][]const u8 = undefined;
    inline for (st.@"struct".fields, 0..) |field, i| {
        fields[i] = field.name;
    }
    const result = fields;
    return &result;
}
test "getting field names" {
    const fields = fieldNames(struct {
        a: usize,
        b: i32,
        c: []const u8,
    });
    try t.expectEqual(3, fields.len);
    try t.expectEqualStrings("a", fields[0]);
    try t.expectEqualStrings("b", fields[1]);
    try t.expectEqualStrings("c", fields[2]);

    for (fields) |f| {
        std.debug.print("field name: {s}\n", .{f});
    }
}

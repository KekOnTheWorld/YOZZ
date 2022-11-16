const std = @import("std");

pub fn clone(src: []u8, allocator: std.mem.Allocator) ![]u8 {
    const buf = try allocator.alloc(u8, src.len);
    std.mem.copy(u8, buf, src);
    return buf;
}
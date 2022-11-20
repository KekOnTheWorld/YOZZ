pub const stack = @import("stack.zig");

const std = @import("std");
const mem = std.mem;

/// Clones an Array by allocating memory on the Stack
/// Must be manually cleared and should not be used
/// in high performance applications!
pub fn clone(comptime T: type, src: []const T, allocator: mem.Allocator) ![]T {
    var dest = try allocator.alloc(T, src.len);
    mem.copy(T, dest, src);
    return dest;
}
const std = @import("std");
const mem = std.mem;

pub const StackBuf = Stack(u8);

pub fn Stack(
    comptime T: type
) type {
    return struct {
        const Self = @This();

        buf: []T,
        len: usize = 0,
        cap: usize,
        allocator: mem.Allocator,

        /// Initialize a new Stack. This will allocate a u8 array
        /// with cap as its size. If allocation fails, an error
        /// Will be returned.
        pub fn init(allocator: mem.Allocator, cap: usize) !Self {
            return Self {
                .cap = cap,
                .buf = try allocator.alloc(T, cap),
                .allocator = allocator
            };
        }

        /// Deinitialize the Stack. This will free the buffer.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buf);
        }

        /// Will set self.len to 0.
        /// Items are not removed from the buffer.
        pub fn reset(self: *Self) void {
            self.len = 0;
        }

        /// Push an item on to the stack and increase the len value.
        /// Might override previous values stored at that position in the buffer.
        pub fn push(self: *Self, item: T) void {
            if(self.len >= self.cap) unreachable;
            self.buf[self.len] = item;
            self.len += 1;
        }

        /// Pops from the stack by decreasing the len value.
        /// Items are not removed from the buffer.
        pub fn pop(self: *Self) void {
            if(self.len > 0) self.len -= 1;
        }

        /// Returns the last element from the stack
        pub fn last(self: *Self) ?T {
            return if(self.len > 0) self.buf[self.len - 1]
                else null;
        }

        /// Get a slice of the buffer with the length of self.len.
        pub fn slice(self: *Self) []T {
            return self.buf[0..self.len];
        }
    };
}
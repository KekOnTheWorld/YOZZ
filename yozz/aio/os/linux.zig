/// TODO: IMPLEMENT
/// Provide asynchronous IO for Linux based
/// Systems
const std = @import("std");
const os = std.os;
const net = std.net;
const mem = std.mem;

const aio = @import("../aio.zig");

const IO_Uring = os.linux.IO_Uring;

pub const IO_URING_DEFAULT_ENTRIES = 128;

/// Wrapper around os.socket_t (supporting asynchronous io)
pub const Socket = struct {
    const Self = @This();

    sockfd: os.socket_t,
    allocator: mem.Allocator,
    ring: IO_Uring,

    /// Initialize a new Socket instance
    pub fn init(allocator: mem.Allocator, socket_type: u32) !Self {
        const sockfd = try os.socket(os.AF.INET6, socket_type, 0);
        errdefer os.close(sockfd);

        // Enable reuseaddr if possible
        os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEPORT,
            &mem.toBytes(@as(c_int, 1)),
        ) catch {};

        // Disable IPv6 only
        try os.setsockopt(
            sockfd,
            os.IPPROTO.IPV6,
            os.linux.IPV6.V6ONLY,
            &mem.toBytes(@as(c_int, 0)),
        );

        return Self{ .sockfd = sockfd, .allocator = allocator, .ring = try IO_Uring.init(IO_URING_DEFAULT_ENTRIES, 0) };
    }

    pub fn bind(self: *Self, addr: net.Address) !void {
        try os.bind(self.sockfd, &addr.any, @sizeOf(os.sockaddr.in6));
    }

    pub fn listen(self: Self) !void {
        try os.listen(self.sockfd, std.math.maxInt(u31));
    }

    pub fn handle() void {}
};

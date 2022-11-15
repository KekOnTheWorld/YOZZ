const std = @import("std");
const net = std.net;
const fs = std.fs;

const Allocator = std.mem.Allocator;

const Parser = @import("parser.zig");

pub fn listen(addr: net.Address, allocator: Allocator) !void {
    var listener = net.StreamServer.init(.{});

    defer listener.close();

    try listener.listen(addr);

    std.log.debug("Listening on {}", .{addr});

    while(listener.accept() catch null) |conn| {
        const stream: net.Stream = conn.stream;

        // Make sure the stream gets closed properly after request is handeled
        defer stream.close();

        std.log.debug("Connection from {}", .{conn.address});

        var parser = try Parser.init(allocator, 128);

        var recv_buf: [64]u8 = undefined;
        while(stream.read(&recv_buf) catch null) |recv_len| {
            std.log.debug("Received: {s}", .{recv_buf[0..recv_len]});

            try parser.write(recv_buf[0..recv_len]);
        }
    }
}
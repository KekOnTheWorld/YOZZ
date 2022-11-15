const std = @import("std");
const net = std.net;
const fs = std.fs;

const Allocator = std.mem.Allocator;

const Parser = @import("parser.zig");
const ParseError = Parser.ParseError;

// 

pub const Method = enum {
    GET, HEAD, POST, PUT,
    DELETE, CONNECT, OPTIONS, 
    TRACE, PATCH,

    pub fn parse(method: []u8) ParseError!Method {
        return std.meta.stringToEnum(Method, method) orelse ParseError.InvalidMethod;
    }
};

pub const Version = enum {
    @"HTTP/1.1", @"HTTP/1.2",

    pub fn parse(version: []u8) ParseError!Version {
        return std.meta.stringToEnum(Version, version) orelse ParseError.InvalidVersion;
    }
};

pub const Path = []u8;

pub const Headers = std.StringHashMap([]u8);

pub const Request = struct {
    method: ?Method,
    version: ?Version,
    path: ?Path,
    headers: Headers,

    pub fn init(allocator: Allocator) Request {
        return Request {
            .method = null, .version = null,
            .path = null, .headers = Headers.init(allocator)
        };
    }
    
    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }
};

pub fn parsePath(path: []u8) ParseError!Path {
    return path;
}

// 

pub fn listen(addr: net.Address, allocator: Allocator) !void {
    var listener = net.StreamServer.init(.{});

    defer listener.deinit();

    try listener.listen(addr);

    std.log.debug("Listening on {}", .{addr});

    while(listener.accept() catch null) |conn| {
        const stream: net.Stream = conn.stream;

        // Make sure the stream gets closed properly after request is handeled
        defer {
            std.log.debug("End connection from {}", .{conn.address});
            stream.close();
        }

        std.log.debug("Connection from {}", .{conn.address});

        var parser = try Parser.init(allocator, 128);
        defer parser.deinit();

        var recv_buf: [64]u8 = undefined;
        while(stream.read(&recv_buf) catch null) |recv_len| {
            if(recv_len == 0) break; // EOF

            std.log.debug("Received: {s}", .{recv_buf[0..recv_len]});

            try parser.write(recv_buf[0..recv_len]);
        }
    }
}
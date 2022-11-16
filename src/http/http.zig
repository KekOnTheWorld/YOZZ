const std = @import("std");
const net = std.net;
const fs = std.fs;

const Allocator = std.mem.Allocator;

const _parser = @import("parser.zig");
const ParseError = _parser.ParseError;
const ParseState = _parser.ParseState;
const Parser = _parser.Parser;

const util = @import("../util.zig");

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

pub const Header = struct {
    name: []u8, value: []u8,

    pub fn parse(name: []u8, value: []u8) ParseError!Header {
        return Header {
            .name = name, .value = value
        };
    }
};

pub const Path = []u8;

pub fn parsePath(path: []u8) ParseError!Path {
    return path;
}

// 

const Context = struct {
    stream: net.Stream,
    allocator: Allocator,

    pub fn init(allocator: Allocator, stream: net.Stream) Context {
        return Context {
            .stream = stream,
            .allocator = allocator
        };
    }

    pub fn deinit(_: *Context) void {}
};

pub fn handleOnPath(ctx: *Context, path: Path) !void {
    if(std.mem.eql(u8, path, "/")) {
        _ = try ctx.stream.write("Hello world!");
    }
}

// 

pub fn listen(addr: net.Address, allocator: Allocator) !void {
    var listener = net.StreamServer.init(.{});

    defer listener.deinit();

    try listener.listen(addr);

    std.log.debug("Listening on http://{}", .{addr});

    var parser = try Parser(Context).init(allocator, 256);
    defer parser.deinit();

    parser.on_path = handleOnPath;

    while(listener.accept() catch null) |conn| {
        parser.reset();
        
        const stream: net.Stream = conn.stream;

        // Make sure the stream gets closed properly after request is handeled
        defer {
            std.log.debug("End connection from {}", .{conn.address});
            stream.close();
        }

        std.log.debug("Connection from {}", .{conn.address});

        std.log.debug("---------------------", .{});

        var ctx = Context.init(allocator, stream);
        defer ctx.deinit();

        var recv_buf: [64]u8 = undefined;
        while(stream.read(&recv_buf) catch null) |recv_len| {
            if(recv_len == 0) break; // EOF

            try parser.write(recv_buf[0..recv_len], &ctx);

            if(parser.state == ParseState.FINISHED) break;
        }

        std.log.debug("---------------------", .{});
    }
}
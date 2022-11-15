const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Method = enum(u4) {
    GET = 0, HEAD = 1, POST = 2, PUT = 3,
    DELETE = 4, CONNECT = 5, OPTIONS = 6, 
    TRACE = 7, PATCH = 8
};

pub const ParseError = error {
    MethodNotFound, NotImplemented
};

pub const ParseState = enum(u4) {
    METHOD = 0, PATH = 1, VERSION = 2
};

pub const Stack = struct {
    buf: []u8,
    len: u32,
    cap: u32,

    pub fn init(allocator: Allocator, cap: u32) !Stack {
        const buf = try allocator.alloc(u8, cap);

        return Stack {
            .cap = cap,
            .buf = buf,
            .len = 0
        };
    }

    pub fn reset(self: *Stack) void {
        self.len = 0;
    }

    pub fn push(self: *Stack, byte: u8) void {
        if(self.len >= self.cap) unreachable;
        self.buf[self.len] = byte;
        self.len += 1;
    }
};

method: ?Method,
path: ?[]u8,
state: ParseState,
stack: Stack,
allocator: Allocator,

const Parser = @This();

pub fn init(allocator: Allocator, cap: u32) !Parser {
    return Parser {
        .method = null,
        .path = null,
        .state = @intToEnum(ParseState, 0),
        .allocator = allocator,
        .stack = try Stack.init(allocator, cap)
    };
}

pub fn write(self: *Parser, data: []u8) ParseError!void {
    for(data) |byte| try self.handle(byte);
}

pub fn nextState(self: *Parser) void {
    self.state = @intToEnum(ParseState, @enumToInt(self.state) + 1);
    self.stack.reset();
}

pub fn handle(self: *Parser, byte: u8) ParseError!void {
    return switch(self.state) {
        ParseState.METHOD => {
            if(byte == ' ') {
                self.method = try parseMethod(self.stack.buf);
                std.log.debug("METHOD: {s} -> {?}", .{self.stack.buf, self.method});
                self.nextState();
            } else self.stack.push(byte);
        },
        else => ParseError.NotImplemented
    };
}

pub fn parseMethod(method: []u8) ParseError!Method {
    // Todo: Find better way (that is working too lol)
    // return switch(method) {
    //     "GET" => Method.GET,
    //     "HEAD" => Method.HEAD,
    //     "POST" => Method.POST,
    //     "PUT" => Method.PUT,
    //     "DELETE" => Method.DELETE,
    //     "CONNECT" => Method.CONNECT,
    //     "OPTIONS" => Method.OPTIONS,
    //     "TRACE" => Method.TRACE,
    //     "PATCH" => Method.PATCH,
    //     else => ParseError.MethodNotFound
    // };

    return ParseError.MethodNotFound;
}
const std = @import("std");
const http = @import("http.zig");

const Allocator = std.mem.Allocator;


pub const ParseError = error {
    InvalidMethod, InvalidVersion, NotImplemented
};

pub const ParseState = enum {
    METHOD, PATH, VERSION, HEADER_NAME, HEADER_VALUE
};

pub const Stack = struct {
    buf: []u8,
    len: usize,
    cap: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, cap: usize) !Stack {
        return Stack {
            .cap = cap,
            .buf = try allocator.alloc(u8, cap),
            .len = 0,
            .allocator = allocator
        };
    }

    pub fn deinit(self: *Stack) void {
        self.allocator.free(self.buf);
    }

    pub fn reset(self: *Stack) void {
        self.len = 0;
    }

    pub fn push(self: *Stack, byte: u8) void {
        if(self.len >= self.cap) unreachable;
        self.buf[self.len] = byte;
        self.len += 1;
    }

    pub fn slice(self: *Stack) []u8 {
        return self.buf[0..self.len];
    }
};

header: []u8,
header_len: usize,
state: ParseState,
stack: Stack,
request: http.Request,
allocator: Allocator,

const Parser = @This();

pub fn init(allocator: Allocator, cap: u32) !Parser {
    return Parser {
        .header = try allocator.alloc(u8, cap),
        .header_len = 0,
        .state = @intToEnum(ParseState, 0),
        .stack = try Stack.init(allocator, cap),
        .request = http.Request.init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Parser) void {
    self.allocator.free(self.header);
    self.request.deinit();
    self.stack.deinit();
}

pub fn write(self: *Parser, data: []u8) !void {
    for(data) |byte| try self.handle(byte);
}

pub fn nextState(self: *Parser) void {
    self.state = @intToEnum(ParseState, @enumToInt(self.state) + 1);
    self.stack.reset();
}

pub fn handle(self: *Parser, byte: u8) !void {
    return switch(self.state) {
        ParseState.METHOD => {
            if(byte != ' ') return self.append(byte);

            self.request.method = try http.Method.parse(self.stack.slice());
            self.nextState();
        },
        ParseState.PATH => {
            if(byte != ' ') return self.append(byte);

            self.request.path = try http.parsePath(self.stack.slice());
            self.nextState();
        },
        ParseState.VERSION => {
            if(byte != '\n') return self.append(byte);

            self.request.version = try http.Version.parse(self.stack.slice());
            self.nextState();
        },
        ParseState.HEADER_NAME => {
            if(byte != ' ') return self.append(byte);
           
            const name = self.stack.slice();
            if(name.len == 0) unreachable;

            // Trim the last char (:)
            // Copy into header name buffer
            self.header_len = name.len - 1;
            std.mem.copy(u8, self.header, name[0..self.header_len]);

            self.stack.reset();
            self.state = ParseState.HEADER_VALUE;
        },
        ParseState.HEADER_VALUE => {
            if(byte != '\n') return self.append(byte);

            const value = self.stack.slice();
            if(value.len == 0) unreachable;

            const name = self.header[0..self.header_len];

            std.log.debug("Header: {s}: {s}", .{name, value});

            // TODO: Find temporary workaround to fix contains context issues
            // self.request.headers.put(name, value);

            self.stack.reset();
            self.state = ParseState.HEADER_NAME;
        }
    };
}

pub fn append(self: *Parser, byte: u8) void {
    if(byte == ' ' or byte == '\r' or byte == '\n') return;
    self.stack.push(byte);
}
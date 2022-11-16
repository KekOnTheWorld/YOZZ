const std = @import("std");
const http = @import("http.zig");

const Allocator = std.mem.Allocator;

pub const ParseError = error {
    InvalidMethod, InvalidVersion, NotImplemented
};

pub const ParseState = enum {
    METHOD, PATH, VERSION, HEADER_NAME, HEADER_VALUE, FINISHED
};

pub const Stack = struct {
    buf: []u8,
    len: usize,
    cap: usize,
    allocator: Allocator,

    // Initialize a new Stack. This will allocate a u8 array
    // with cap as its size. If allocation fails, an error
    // Will be returned.
    pub fn init(allocator: Allocator, cap: usize) !Stack {
        return Stack {
            .cap = cap,
            .buf = try allocator.alloc(u8, cap),
            .len = 0,
            .allocator = allocator
        };
    }

    // Deinitialize the Stack. This will free the buffer.
    pub fn deinit(self: *Stack) void {
        self.allocator.free(self.buf);
    }

    // Will set self.len to 0.
    // Items are not removed from the buffer.
    pub fn reset(self: *Stack) void {
        self.len = 0;
    }

    // Push a byte on to the stack and increase the len value.
    // Might override previous values stored at that position in the buffer.
    pub fn push(self: *Stack, byte: u8) void {
        if(self.len >= self.cap) unreachable;
        self.buf[self.len] = byte;
        self.len += 1;
    }

    // Pops from the stack by decreasing the len value.
    // Items are not removed from the buffer.
    // Returns the previous value at the last position.
    pub fn pop(self: *Stack) u8 {
        self.len -= 1;
        return self.buf[self.len];
    }

    // Get a slice of the buffer with the length of self.len.
    pub fn slice(self: *Stack) []u8 {
        return self.buf[0..self.len];
    }
};

pub fn Parser(
    comptime Context: type
) type {
    return struct {
        // Default handlers
        pub fn onMethod(_: *Context, _: http.Method) anyerror!void {}
        pub fn onPath(_: *Context, _: http.Path) anyerror!void {}
        pub fn onVersion(_: *Context, _: http.Version) anyerror!void {}
        pub fn onHeader(_: *Context, _: http.Header) anyerror!void {}
        pub fn onEnd(_: *Context) anyerror!void {}

        header: usize,
        state: ParseState,
        stack: Stack,

        on_method: *const @TypeOf(onMethod),
        on_path: *const @TypeOf(onPath),
        on_version: *const @TypeOf(onVersion),
        on_header: *const @TypeOf(onHeader),
        on_end: *const @TypeOf(onEnd),

        const Self = @This();

        // Initialize the Parser. This will
        // allocate a new Stack with size of cap
        pub fn init(allocator: Allocator, cap: u32) !Self {
            return Self {
                .on_method = onMethod, .on_path = onPath,
                .on_version = onVersion, .on_header = onHeader,
                .on_end = onEnd,
                .header = 0,
                .state = @intToEnum(ParseState, 0),
                .stack = try Stack.init(allocator, cap)
            };
        }

        // Deinitialize the Parser. This will deinitialize
        // its stack and its request object.
        pub fn deinit(self: *Self) void {
            self.stack.deinit();
        }

        // Reset the Parser to its initial State
        pub fn reset(self: *Self) void {
            self.state = @intToEnum(ParseState, 0);
            self.stack.reset();
            self.header = 0;
        }

        // Handle multiple bytes
        pub fn write(self: *Self, data: []u8, ctx: *Context) !void {
            for(data) |byte| try self.handle(byte, ctx);
        }

        // Handle byte
        pub fn handle(self: *Self, byte: u8, ctx: *Context) !void {
            return switch(self.state) {
                ParseState.METHOD => {
                    if(byte != ' ') return self.append(byte);

                    const method = try http.Method.parse(self.stack.slice());

                    std.log.debug("METHOD: {}", .{method});

                    try self.on_method(ctx, method);

                    self.stack.reset();
                    self.state = ParseState.PATH;
                },
                ParseState.PATH => {
                    if(byte != ' ') return self.append(byte);

                    const path = try http.parsePath(self.stack.slice());

                    std.log.debug("PATH: {s}", .{path});

                    try self.on_path(ctx, path);

                    self.stack.reset();
                    self.state = ParseState.VERSION;
                },
                ParseState.VERSION => {
                    if(byte != '\n') return self.append(byte);

                    const version = try http.Version.parse(self.stack.slice());

                    std.log.debug("VERSION: {}", .{version});

                    try self.on_version(ctx, version);

                    self.stack.reset();
                    self.state = ParseState.HEADER_NAME;
                },
                ParseState.HEADER_NAME => {
                    if(byte == '\n') {
                        self.state = ParseState.FINISHED;

                        std.log.debug("END OF MESSAGE", .{});

                        return try self.on_end(ctx);
                    }

                    if(byte != ' ') return self.append(byte);

                    // Pop the ':' char to get the raw header name
                    // We are not using .pop because we don't need a value returned
                    self.stack.len -= 1;

                    // Store the split position between header name and value
                    self.header = self.stack.len;

                    self.state = ParseState.HEADER_VALUE;
                },
                ParseState.HEADER_VALUE => {
                    if(byte != '\n') return self.append(byte);

                    const name = self.stack.buf[0..self.header];
                    const value = self.stack.buf[self.header..self.stack.len];

                    const header = try http.Header.parse(name, value);

                    std.log.debug("HEADER: {s}: {s}", .{header.name, header.value});

                    try self.on_header(ctx, header);

                    self.stack.reset();
                    self.state = ParseState.HEADER_NAME;
                },
                ParseState.FINISHED => {}
            };
        }

        // Append byte to stack
        pub fn append(self: *Self, byte: u8) void {
            if(byte == '\r' or byte == '\n') return;
            self.stack.push(byte);
        }
    };
}
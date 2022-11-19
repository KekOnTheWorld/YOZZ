const std = @import("std");
const http = @import("http.zig");
const StackBuf = @import("../util/stack.zig").StackBuf;

const Allocator = std.mem.Allocator;

pub const ParseState = enum {
    METHOD, PATH, VERSION, HEADER_NAME, HEADER_VALUE, FINISHED
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
        stack: StackBuf,

        on_method: *const @TypeOf(onMethod) = onMethod,
        on_path: *const @TypeOf(onPath) = onPath,
        on_version: *const @TypeOf(onVersion) = onVersion,
        on_header: *const @TypeOf(onHeader) = onHeader,
        on_end: *const @TypeOf(onEnd) = onEnd,

        const Self = @This();

        // Initialize the Parser. This will
        // allocate a new Stack with size of cap
        pub fn init(allocator: Allocator, stack_cap: usize) !Self {
            return Self {
                .header = 0,
                .state = @intToEnum(ParseState, 0),
                .stack = try StackBuf.init(allocator, stack_cap)
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

                    // Pop the ':' from the stack
                    self.stack.pop();

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
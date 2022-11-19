const std = @import("std");
const mem = std.mem;

const stack = @import("../util/stack.zig");
const StackBuf = stack.StackBuf;
const Stack = stack.Stack;

const http = @import("../http/http.zig");

pub const ParseState = enum {
    INSTRUCTION, 
    
    ROUTE_METHOD,
    ROUTE_URL,

    GROUP_NAME,

    ERROR_STATUS, 
    
    RETURN_STATUS,
    RETURN_BODY,

    LAYOUT_HANDLER,
    RENDER_HANDLER,
    MIDDLEWARE_HANDLER,

    BODY,

    COMMENT,
};

pub const BodyType = enum {
    GROUP, ROUTE, ERROR
};
pub const Body = struct { single: bool, typ: BodyType };
pub const BodyStack = Stack(Body);

pub const ParseError = error {
    INVALID_INSTRUCTION, 
    UNEXPECTED_NEW_LINE,
    INVALID_HANDLER,
    EXPECTED_BODY_START,
    UNEXPECTED_BODY_END,
    EMPTY_SINGLE_BODY
};

pub const Instruction = enum {
    GROUP, ROUTE, ERROR, LAYOUT, MIDDLEWARE, RENDER, RETURN,

    pub fn parse(instruction: []const u8) ParseError!Instruction {
        return std.meta.stringToEnum(Instruction, instruction)
            orelse ParseError.INVALID_INSTRUCTION;
    }
};

pub const Handler = struct {
    buf: []const u8,

    pub fn parse(buf: []const u8) ParseError!Handler {
        // TODO: correctly parse header
        return Handler {
            .buf = buf
        };
    }
};

pub const GroupStack = Stack(u16);

pub fn Parser(
    comptime Context: type
) type {
    return struct {
        const KeyStack = struct {};

        const Self = @This();

        
        pub fn onGroupBegin(_: *Context, _: u16, _: []const u8) void {}
        pub fn onGroupEnd(_: *Context, _: u16) void {}
        pub fn onRouteBegin(_: *Context, _: http.Method, _: http.Path) void {}
        pub fn onRouteEnd(_: *Context) void {}
        pub fn onErrorBegin(_: *Context, _: http.Status) void {}
        pub fn onErrorEnd(_: *Context) void {}
        pub fn onLayout(_: *Context, _: Handler) void {}
        pub fn onMiddleware(_: *Context, _: Handler) void {}
        pub fn onRender(_: *Context, _: Handler) void {}
        pub fn onReturn(_: *Context, _: http.Status, _: []const u8) void {}
        pub fn onComment(_: *Context, _: []const u8) void {}

        /// onGroupBegin(ctx, gid, name)
        on_group_begin: *const @TypeOf(onGroupBegin) = onGroupBegin,
        /// onGroupEnd(ctx, gid)
        on_group_end: *const @TypeOf(onGroupEnd) = onGroupEnd,
        /// onRouteBegin(ctx, method, path)
        on_route_begin: *const @TypeOf(onRouteBegin) = onRouteBegin,
        /// onRouteEnd(ctx)
        on_route_end: *const @TypeOf(onRouteEnd) = onRouteEnd,
        /// onErrorBegin(ctx, status)
        on_error_begin: *const @TypeOf(onErrorBegin) = onErrorBegin,
        /// onErrorEnd(ctx)
        on_error_end: *const @TypeOf(onErrorEnd) = onErrorEnd,
        /// onLayout(ctx, handler)
        on_layout: *const @TypeOf(onLayout) = onLayout, 
        /// onMiddleware(ctx, handler)
        on_middleware: *const @TypeOf(onMiddleware) = onMiddleware,
        /// onRender(ctx, handler)
        on_render: *const @TypeOf(onRender) = onRender,
        /// onReturn(ctx, status, body)
        on_return: *const @TypeOf(onReturn) = onReturn,
        /// onComment(ctx, comment)
        on_comment: *const @TypeOf(onComment) = onComment,

        stack: StackBuf,
        
        // Up to 65535 groups
        group_id: u16 = 0,
        group_stack: GroupStack, 

        route_method: http.Method = undefined,

        return_status: http.Status = undefined,

        body_stack: BodyStack,
        body_type: BodyType,

        allocator: mem.Allocator,
        state: ParseState,

        pub fn init(allocator: mem.Allocator, stack_cap: usize, group_depth: u4, body_depth: u4) !Self {
            return Self {
                .stack = try StackBuf.init(allocator, stack_cap),
                .group_stack = try GroupStack.init(allocator, group_depth),
                .body_stack = try BodyStack.init(allocator, body_depth),
                .allocator = allocator,
                .state = @intToEnum(ParseState, 0)
            };
        }

        pub fn deinit(self: *Self) void {
            self.stack.deinit();
            self.group_stack.deinit();
        }

        pub fn write(self: *Self, buf: []const u8, ctx: *Context) !void {
            for(buf) |byte| try self.handle(byte, ctx);
        }

        /// Pops body from the stack if single
        pub fn popBody(self: *Self) void {
            if(self.body_stack.last()) |body| {
                if(body.single) self.body_stack.pop();
            }
        }
        
        pub fn handle(self: *Self, byte: u8, ctx: *Context) !void {
            return switch(self.state) {
                ParseState.INSTRUCTION => {
                    if(byte == '}') {
                        if(self.body_stack.last()) |body| {
                            if(body.single) {
                                return ParseError.EMPTY_SINGLE_BODY;
                            } else self.body_stack.pop();
                        } else return ParseError.UNEXPECTED_BODY_END;
                    }

                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    if(byte == '\n') return ParseState.UNEXPECTED_NEW_LINE;

                    self.stack.reset();
                    self.state = switch(try Instruction.parse(self.stack.slice())) {
                        Instruction.GROUP => ParseState.GROUP_NAME,
                        Instruction.ROUTE => ParseState.ROUTE_METHOD,
                        Instruction.ERROR => ParseState.ERROR_STATUS,

                        Instruction.LAYOUT => ParseState.LAYOUT_HANDLER,
                        Instruction.MIDDLEWARE => ParseState.MIDDLEWARE_HANDLER,
                        Instruction.RENDER => ParseState.RENDER_HANDLER,

                        Instruction.RETURN => ParseState.RETURN_STATUS
                    };
                },
                ParseState.GROUP_NAME => {
                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    const gid = self.group_id;
                    self.group_stack.push(gid);
                    self.group_id += 1;

                    self.on_group_begin(ctx, gid, self.stack.slice());

                    self.stack.reset();

                    self.body_type = BodyType.GROUP;
                    self.state = ParseState.BODY;
                },
                ParseState.ROUTE_METHOD => {
                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    if(byte == '\n')
                        return ParseError.UNEXPECTED_NEW_LINE;

                    self.route_method = try http.Method.parse(self.stack.slice());

                    self.stack.reset();
                    self.state = ParseState.ROUTE_URL;
                },
                ParseState.ROUTE_URL => {
                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    self.on_route_begin(ctx, self.route_method, try http.parsePath(self.stack.slice()));

                    self.stack.reset();

                    self.body_type = BodyType.ROUTE;
                    self.state = ParseState.BODY;
                },
                ParseState.ERROR_STATUS => {
                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    self.on_error_begin(ctx, try http.Status.parse(
                        try std.fmt.parseInt(self.stack.slice())));

                    self.stack.reset();

                    self.body_type = BodyType.ERROR;
                    self.state = ParseState.BODY;
                },
                ParseState.LAYOUT_HANDLER => {
                    if(byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    self.on_layout(ctx, try Handler.parse(self.stack.slice()));

                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;

                    self.popBody();
                },
                ParseState.MIDDLEWARE_HANDLER => {
                    if(byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    self.on_middleware(ctx, try Handler.parse(self.stack.slice()));

                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;

                    self.popBody();
                },
                ParseState.RENDER_HANDLER => {
                    if(byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    self.on_render(ctx, try Handler.parse(self.stack.slice()));

                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;

                    self.popBody();
                },
                ParseState.RETURN_STATUS => {
                    if(byte != ' ' and byte != '\n')
                        return self.stack.push(byte);
                    if(self.stack.len == 0) return;

                    if(byte == '\n')
                        return ParseError.UNEXPECTED_NEW_LINE;

                    self.return_status = try http.Status.parse(
                        try std.fmt.parseInt(self.stack.slice()));

                    self.stack.reset();
                    self.state = ParseState.RETURN_BODY;
                },
                ParseState.RETURN_BODY => {
                    if(byte != '\n')
                        return self.stack.push(byte);
                    
                    self.on_return(ctx, self.return_status, self.stack.slice());
                
                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;

                    self.popBody();
                },
                ParseState.COMMENT => {
                    if(byte != '\n')
                        return self.stack.push(byte);
                    
                    self.on_comment(ctx, self.stack.slice());

                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;
                },
                ParseState.BODY => {
                    if(byte != '\n' and byte != ' ')
                        return self.stack.push(byte);
                    

                    var single: bool = false;
                    if(mem.eql(self.stack.slice(), "=>")) {
                        single = true;
                    } else if(!mem.eql(self.stack.slice(), "{"))
                        return ParseError.EXPECTED_BODY_START;

                    self.body_stack.push(Body {
                        .single = single,
                        .typ = self.body_type
                    });

                    self.stack.reset();
                    self.state = ParseState.INSTRUCTION;
                }
            };
        }
    };
}



const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const yozz = @import("yozz.zig");
const http = yozz.http;
const util = yozz.util;

const logger = std.log.scoped(.YOZZ_CODEGEN);

const Instruction = union(enum) {
    render_handler: []const u8,
    layout_handler: []const u8,
    middleware_handler: []const u8,

    pub fn deinit(self: Instruction, allocator: mem.Allocator) void {
        switch(self) {
            .render_handler => allocator.free(self.render_handler),
            .layout_handler => allocator.free(self.layout_handler),
            .middleware_handler => allocator.free(self.middleware_handler),
        }
    }
};

const Route = struct {
    path: http.Path, method: http.Method,
    instructions: std.ArrayList(Instruction),

    pub fn init(path: http.Path, method: http.Method, allocator: mem.Allocator) !Route {
        return Route {
            .instructions = std.ArrayList(Instruction).init(allocator),
            .path = path, .method = method
        };
    }

    pub fn deinit(self: Route) void {
        const allocator = self.instructions.allocator;
        for(self.instructions.items) |item| {
            item.deinit(allocator);
        }
        allocator.free(self.path);
        self.instructions.deinit();
    }
};

const Context = struct {
    src: fs.Dir, dest: fs.Dir,
    allocator: mem.Allocator,

    route: ?Route = null,
    routes: std.StringHashMap(Route),

    pub fn init(src: fs.Dir, dest: fs.Dir, allocator: mem.Allocator) !Context {
        return Context {
            .src = src,
            .dest = dest,
            .allocator = allocator,
            .routes = std.StringHashMap(Route).init(allocator)
        };
    }

    pub fn deinit(self: *Context) void {
        var iterator = self.routes.valueIterator();
        while(iterator.next()) |item| {
            item.deinit();
        }

        self.routes.deinit();
    }

    pub fn onRouteBegin(self: *Context, method: http.Method, path: http.Path) !void {
        logger.info("ROUTE BEGIN: {any}: {s}", .{method, path});

        self.route = try Route.init(try util.clone(u8, path, self.allocator), 
            method, self.allocator);
    }

    pub fn onRender(self: *Context, handler: []const u8) !void {
        logger.info("RENDER: HANDLER: {s}", .{handler});
        
        if(self.route) |*route| {
            try route.instructions.append(Instruction {
                .render_handler = try util.clone(u8, handler, self.allocator)
            });
        }
    }

    pub fn onLayout(self: *Context, handler: []const u8) !void {
        logger.info("LAYOUT: HANDLER: {s}", .{handler});

        if(self.route) |*route| {
            try route.instructions.append(Instruction {
                .layout_handler = try util.clone(u8, handler, self.allocator)
            });
        }
    }
   
    pub fn onMiddleware(self: *Context, handler: []const u8) !void {
        logger.info("MIDDLEWARE: HANDLER: {s}", .{handler});
        
        if(self.route) |*route| {
            try route.instructions.append(Instruction {
                .middleware_handler = try util.clone(u8, handler, self.allocator)
            });
        }
    }

    pub fn onRouteEnd(self: *Context) !void {
        // Merge route instructions on collision
        var route = self.route.?;
        var result = try self.routes.getOrPut(route.path);
        if(result.found_existing) {
            try result.value_ptr.instructions.appendSlice(route.instructions.items);
            route.instructions.clearAndFree();
            route.deinit();
        } else result.value_ptr.* = route;
        self.route = null;
    }

    pub fn append(parser: *yozz.Parser(Context)) void {
        parser.on_route_begin = onRouteBegin;
        parser.on_route_end = onRouteEnd;
        parser.on_render = onRender;
        parser.on_layout = onLayout;
        parser.on_middleware = onMiddleware;
    }
};

pub fn load(src: fs.Dir, dest: fs.Dir, allocator: mem.Allocator) !void {
    const config: fs.File = try src.openFile("config.yozz", .{});

    var parser = try yozz.Parser(Context).init(allocator, 128, 4, 4);
    Context.append(&parser);
    defer parser.deinit();

    var ctx = try Context.init(src, dest, allocator);
    defer ctx.deinit();

    var buf: [32]u8 = undefined;
    while (config.read(&buf) catch null) |bytes| {
        const slice = buf[0..bytes];

        try parser.write(slice, &ctx);

        if (bytes < buf.len) break;
    }
}
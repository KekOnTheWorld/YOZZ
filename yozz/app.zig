const std = @import("std");
const fs = std.fs;

const _parser = @import("parser/parser.zig");
const Parser = _parser.Parser;

const logger = std.log.scoped(.YOZZ_APP);

const Context = struct {
    pub fn init() !Context {
        return Context {};
    }

    pub fn onComment(self: *Context, comment: []const u8) !void {
        _ = self; std.log.info("COMMENT: {s}", .{comment});
    }
};

const onComment = Context.onComment;

pub fn prepare(exe: *std.build.LibExeObjStep) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if(gpa.deinit()) logger.info("kekw", .{});
    const allocator = gpa.allocator();

    logger.info("Preparing to build '{s}'", .{exe.name});

    const src_relative_path = fs.path.dirname(exe.root_src.?.path).?;
    const src_absolute_path = try fs.path.resolve(allocator, &[_][]const u8{src_relative_path});
    defer allocator.free(src_absolute_path);

    const src_root: fs.Dir = try fs.openDirAbsolute(src_absolute_path, .{});

    const config: fs.File = try src_root.openFile("config.yozz", .{});

    var parser = try Parser(Context).init(allocator, 128, 4, 4);
    defer parser.deinit();
    var ctx = try Context.init();
    
    parser.on_comment = onComment;


    var buf: [32]u8 = undefined;
    while(config.read(&buf) catch null) |bytes| {
        const slice = buf[0..bytes];

        try parser.write(slice, &ctx);

        if(bytes < buf.len) break;
    }
    
}
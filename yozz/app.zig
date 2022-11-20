const std = @import("std");
const fs = std.fs;

const http = @import("http/http.zig");

const codegen = @import("codegen.zig");

const logger = std.log.scoped(.YOZZ_APP);

pub fn prepare(exe: *std.build.LibExeObjStep) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit()) logger.info("kekw", .{});
    const allocator = gpa.allocator();

    logger.info("Preparing to build '{s}'", .{exe.name});

    // TODO: pass as argument
    const src_path = fs.path.dirname(exe.root_src.?.path).?;
    logger.info("Using source directory '{s}'", .{src_path});
    const src: fs.Dir = try fs.cwd().openDir(src_path, .{});

    // TODO: pass as argument
    const dest_path = "__yozz__/generated";
    try fs.cwd().makePath(dest_path);
    logger.info("Using destination directory '{s}'", .{dest_path});
    const dest: fs.Dir = try fs.cwd().openDir(dest_path, .{});

    try codegen.load(src, dest, allocator);   
}

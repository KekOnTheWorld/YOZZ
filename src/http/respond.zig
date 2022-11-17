const std = @import("std");
const net = std.net;
const fs = std.fs;

const http = @import("http.zig");

pub fn writeStatus(stream: net.Stream, comptime version: http.Version, comptime status: http.Status) !void {
    const status_line = comptime version.toString() ++ " " ++ status.toString() ++ "\r\n";

    std.debug.assert(try stream.write(status_line) == status_line.len);
}

pub fn writeHeader(stream: net.Stream, comptime header: http.Header) !void {
    const header_line = header.name ++ ": " ++ header.value ++ "\r\n";

    std.debug.assert(try stream.write(header_line) == header_line.len);
}

pub fn writeBody(stream: net.Stream, buf: []const u8, comptime typ: []const u8) !void {
    try writeBodyLine(stream, buf.len, typ);

    std.debug.assert(try stream.write(buf) == buf.len);
}

pub fn writeBodyLine(stream: net.Stream, len: usize, comptime typ: []const u8) !void {
    // 11 for the number, 38 for the rest
    var body_line_buf: [11 + typ.len + 38]u8 = undefined;
    const body_line = try std.fmt.bufPrint(&body_line_buf, "Content-Length: {d}\r\nContent-Type: " ++ typ ++ "\r\n\r\n", .{len});

    std.debug.assert(try stream.write(body_line) == body_line.len);
}

pub fn writeFile(stream: net.Stream, dir: fs.Dir, name: []const u8, comptime typ: []const u8) !void {
    const file: fs.File = try dir.openFile(name, .{});
    defer file.close();

    const size: usize = (try file.stat()).size;

    try writeBodyLine(stream, size, typ);

    var buf: [128]u8 = undefined;
    while(file.read(&buf) catch null) |bytes_read| {
        std.debug.assert(try stream.write(buf[0..bytes_read]) == bytes_read);

        if(bytes_read < buf.len) break;
    }
}
const std = @import("std");
const net = std.net;

const http = @import("http.zig");

pub fn writeStatus(comptime version: http.Version, comptime status: http.Status, stream: net.Stream) !void {
    const status_line = comptime version.toString() ++ " " ++ status.toString() ++ "\r\n";

    std.debug.assert(try stream.write(status_line) == status_line.len);
}

pub fn writeHeader(comptime header: http.Header, stream: net.Stream) !void {
    const header_line = header.name ++ ": " ++ header.value ++ "\r\n";

    std.debug.assert(try stream.write(header_line) == header_line.len);
}

pub fn writeBody(body: http.Body, stream: net.Stream) !void {
    // 11 for the number, 38 for the rest
    var body_line_buf: [11 + body.typ.len + 38]u8 = undefined;
    const body_line = try std.fmt.bufPrint(&body_line_buf, "Content-Length: {d}\r\nContent-Type: " ++ body.typ ++ "\r\n\r\n", .{body.buf.len});

    std.debug.assert(try stream.write(body_line) == body_line.len);
    std.debug.assert(try stream.write(body.buf) == body.buf.len);
}
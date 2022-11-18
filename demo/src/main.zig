// YOZZ EXAMPLE PROJECT

const std = @import("std");
const http = @import("http/http.zig");
const assert = std.debug.assert;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var port: u16 = 4000;

    while((http.listen(try std.net.Address.resolveIp("0.0.0.0", port), allocator) catch null) == null) {
        std.log.warn("Port {} in use. Trying another one...", .{port});
        port += 1;
    }
}
const std = @import("std");
const net = std.net;

const http = @import("http.zig");

const Respond = @This();

stream: net.Stream,
version: http.Version,
method: http.Method,
status: u16,

pub fn init(stream: net.Stream) Respond {
    return Respond { .stream = stream };
}
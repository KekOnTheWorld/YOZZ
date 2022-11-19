const std = @import("std");
const fs = std.fs;

const logger = std.log.scoped(.YOZZ_APP);

pub fn prepare(exe: *std.build.LibExeObjStep) void {
    logger.info("Preparing to build {s}", .{exe.name});
}
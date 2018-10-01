const std = @import("std");
const mem = std.mem;

const FmtErrors = error {};

fn fmtCallback(result: *[]const u8, output: []const u8) FmtErrors!void {
    result.* = output;
}

pub fn fmt(comptime s: []const u8, args: ...) []const u8 {
    var result: []const u8 = undefined;
    try std.fmt.format(&result, FmtErrors, fmtCallback, s, args);
    return result;
}


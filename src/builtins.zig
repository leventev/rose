const std = @import("std");

const rook = @import("rook/rook.zig");

pub fn builtin_echo(args: []const []const u8) !void {
    var bufwriter = std.io.bufferedWriter(rook.io.out.writer());
    const writer = bufwriter.writer();
    if (args.len > 0) {
        try writer.writeAll(args[0]);
        for (args[1..]) |arg| try writer.print(" {s}", .{arg});
    }
    try writer.writeByte('\n');
    try bufwriter.flush();
}

pub fn builtin_pwd(_: []const []const u8) !void {
    var buff: [rook.PATH_FULL_MAX]u8 = undefined;
    const written = try rook.fd2path(rook.CWD_FD, &buff);
    try builtin_echo(&.{buff[0..written]});
}

const std = @import("std");

const rook = @import("rook/rook.zig");
const env = @import("env.zig");

pub fn builtin_echo(args: []const []const u8) !void {
    var buff_writer = std.io.bufferedWriter(rook.io.out.writer());
    const writer = buff_writer.writer();

    if (args.len > 0) {
        try writer.writeAll(args[0]);
        for (args[1..]) |arg| try writer.print(" {s}", .{arg});
    }

    try writer.writeByte('\n');
    try buff_writer.flush();
}

pub fn builtin_pwd(_: []const []const u8) !void {
    var buff: [rook.PATH_FULL_MAX]u8 = undefined;
    const written = try rook.fd2path(rook.CWD_FD, &buff);
    try builtin_echo(&.{buff[0..written]});
}

pub fn builtin_env(_: []const []const u8) !void {
    var iter = try env.get_env_iterator();

    var buff_writer = std.io.bufferedWriter(rook.io.out.writer());
    const writer = buff_writer.writer();

    while (iter.next()) |envvar| {
        try writer.print("{s}={s}\n", .{ envvar.key_ptr.*, envvar.value_ptr.* });
    }

    try buff_writer.flush();
}

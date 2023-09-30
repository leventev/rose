const std = @import("std");
const rook = @import("rook/rook.zig");
const Env = @import("env.zig").Env;

pub fn builtinEcho(_: *Env, args: []const []const u8) !void {
    var buff_writer = std.io.bufferedWriter(rook.io.out.writer());
    const writer = buff_writer.writer();

    if (args.len > 0) {
        try writer.writeAll(args[0]);
        for (args[1..]) |arg| try writer.print(" {s}", .{arg});
    }

    try writer.writeByte('\n');
    try buff_writer.flush();
}

pub fn builtinPwd(env: *Env, _: []const []const u8) !void {
    var buff: [rook.PATH_FULL_MAX]u8 = undefined;
    const written = try rook.fd2path(rook.CWD_FD, &buff);
    try builtinEcho(env, &.{buff[0..written]});
}

pub fn builtinEnv(env: *Env, _: []const []const u8) !void {
    var iter = env.getEnvIterator();

    var buff_writer = std.io.bufferedWriter(rook.io.out.writer());
    const writer = buff_writer.writer();

    while (iter.next()) |envvar| {
        try writer.print("{s}={s}\n", .{ envvar.key_ptr.*, envvar.value_ptr.* });
    }

    try buff_writer.flush();
}

const std = @import("std");
const rook = @import("rook/rook.zig");
const builtins = @import("builtins.zig");

const builtin_cmd = *const fn (args: [][]const u8) anyerror!void;
const builtin_kv = struct { []const u8, builtin_cmd };
const builtin_commands = std.ComptimeStringMap(builtin_cmd, [_]builtin_kv{
    .{ "echo", builtins.builtin_echo },
    .{ "pwd", builtins.builtin_pwd },
});

fn handle_command(args: [][]const u8) !void {
    const command = args[0];
    const rest = args[1..];

    if (builtin_commands.get(command)) |cmd| {
        try cmd(rest);
    } else {
        try handle_external(command, rest);
    }
}

pub fn handle_line(line: []const u8) !void {
    const args = try parse_line(line);
    errdefer args.deinit();

    try handle_command(args.items);
}

fn parse_line(line: []const u8) !std.ArrayList([]const u8) {
    var iter = std.mem.splitAny(u8, line, " ");
    var args = std.ArrayList([]const u8).init(rook.page_allocator);

    while (iter.next()) |part| {
        const copied = try rook.page_allocator.dupe(u8, part);
        try args.append(copied);
    }

    return args;
}

fn handle_external(cmd: []const u8, args: [][]const u8) !void {
    _ = args;
    _ = cmd;
}

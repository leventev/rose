const std = @import("std");
const rook = @import("rook/rook.zig");
const builtins = @import("builtins.zig");

const builtin_cmd = *const fn (args: []const []const u8) anyerror!void;
const builtin_commands = std.ComptimeStringMap(builtin_cmd, .{
    .{ "echo", builtins.builtin_echo },
    .{ "pwd", builtins.builtin_pwd },
});

fn handle_command(args: []const []const u8) !void {
    const command = args[0];
    const rest = args[1..];

    if (builtin_commands.get(command)) |cmd| {
        try cmd(rest);
    } else {
        try handle_external(command, rest);
    }
}

pub fn handle_line(allocator: std.mem.Allocator, line: []const u8) !void {
    const args = try parse_line(allocator, line);
    defer args.deinit();

    try handle_command(args.items);
}

fn parse_line(allocator: std.mem.Allocator, line: []const u8) !std.ArrayList([]const u8) {
    var iter = std.mem.tokenizeScalar(u8, line, ' ');
    var args = std.ArrayList([]const u8).init(allocator);
    errdefer args.deinit();
    while (iter.next()) |part| try args.append(part);
    return args;
}

fn handle_external(cmd: []const u8, args: []const []const u8) !void {
    _ = args;
    _ = cmd;
}

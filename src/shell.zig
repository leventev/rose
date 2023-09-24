const std = @import("std");
const rook = @import("rook/rook.zig");
const builtins = @import("builtins.zig");
const Env = @import("env.zig").Env;

const builtin_cmd = *const fn (env: *Env, args: []const []const u8) anyerror!void;
const builtin_commands = std.ComptimeStringMap(builtin_cmd, .{
    .{ "echo", builtins.builtin_echo },
    .{ "pwd", builtins.builtin_pwd },
    .{ "env", builtins.builtin_env },
});

pub const Shell = struct {
    allocator: std.mem.Allocator = undefined,
    env: Env = undefined,

    pub fn init(allocator: std.mem.Allocator, envp: [*:null]const ?[*:0]const u8) !Shell {
        return .{
            .allocator = allocator,
            .env = try Env.init(allocator, envp),
        };
    }

    fn handle_command(self: *Shell, args: []const []const u8) void {
        const command = args[0];
        const rest = args[1..];

        if (builtin_commands.get(command)) |cmd| {
            cmd(&self.env, rest) catch @panic("Builtin failed");
        } else {
            self.handle_external(command, rest) catch |err| {
                const writer = rook.io.out.writer();
                writer.print("rose: {s}: command not found: {s}\n", .{ command, @errorName(err) }) catch {};
            };
        }
    }

    fn handle_line(self: *Shell, line: []const u8) void {
        const args = self.parse_line(line) catch @panic("Failed to parse line");
        defer args.deinit();

        self.handle_command(args.items);
    }

    fn parse_line(self: *Shell, line: []const u8) !std.ArrayList([]const u8) {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        var args = std.ArrayList([]const u8).init(self.allocator);
        errdefer args.deinit();
        while (iter.next()) |part| try args.append(part);
        return args;
    }

    fn find_exec(self: *Shell, name: []const u8) void {
        _ = self;
        _ = name;
    }

    fn handle_external(self: *Shell, cmd: []const u8, args: []const []const u8) !void {
        _ = self;
        _ = args;
        if (std.mem.startsWith(u8, cmd, "/")) {
            const fd = try rook.open(cmd);
            try rook.io.out.writer().print("opened {}\n", .{fd});
        }
    }

    const PROMPT: []const u8 = "$ ";

    fn print_prompt() !void {
        _ = try rook.io.out.writeAll(PROMPT);
    }

    const MAX_LINE_LEN = 4096;

    pub fn read_loop(self: *Shell) noreturn {
        var line_buff: [MAX_LINE_LEN]u8 = undefined;
        var buff_stream = std.io.fixedBufferStream(&line_buff);

        const stdin_reader = rook.io.in.reader();
        while (true) : (buff_stream.reset()) {
            print_prompt() catch {};
            stdin_reader.streamUntilDelimiter(buff_stream.writer(), '\n', MAX_LINE_LEN) catch @panic("Failed to read line from stdin");
            if (buff_stream.getPos() catch unreachable == 0) continue;
            self.handle_line(buff_stream.getWritten());
        }
    }
};

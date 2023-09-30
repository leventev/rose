const std = @import("std");
const rook = @import("rook/rook.zig");
const builtins = @import("builtins.zig");
const Env = @import("env.zig").Env;

const builtin_cmd = *const fn (env: *Env, args: []const []const u8) anyerror!void;
const builtin_commands = std.ComptimeStringMap(builtin_cmd, .{
    .{ "echo", builtins.builtinEcho },
    .{ "pwd", builtins.builtinPwd },
    .{ "env", builtins.builtinEnv },
});

pub const Shell = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    env: Env,

    pub fn init(allocator: std.mem.Allocator, envp: [*:null]const ?[*:0]const u8) !Shell {
        return .{
            .allocator = allocator,
            .env = try Env.init(allocator, envp),
        };
    }

    fn handleCommand(self: *Self, args: []const []const u8) void {
        const command = args[0];
        const rest = args[1..];

        if (builtin_commands.get(command)) |cmd| {
            cmd(&self.env, rest) catch @panic("Builtin failed");
        } else {
            self.handleExternal(command, rest) catch |err| {
                const writer = rook.io.out.writer();
                writer.print("rose: {s}: command not found: {s}\n", .{ command, @errorName(err) }) catch {};
            };
        }
    }

    fn handleLine(self: *Self, line: []const u8) void {
        const args = self.parseLine(line) catch @panic("Failed to parse line");
        defer args.deinit();
        defer for (args.items) |arg| self.allocator.free(arg);

        self.handleCommand(args.items);
    }

    fn expandArgument(self: *Self, arg: []const u8) std.mem.Allocator.Error![]const u8 {
        var str = std.ArrayList(u8).init(self.allocator);

        var index: usize = 0;
        while (index < arg.len) : (index += 1) {
            const ch = arg[index];
            // if we find a $ it means we are trying to look up a variable
            if (ch == '$') {
                // find the end of the key, usually a whitespace, slash, dot, etc...
                const key_end = findNextNonAlphanumeric(arg, index + 1) orelse arg.len;

                if (key_end == index + 1) {
                    // if the key's length is 0 just write a $
                    try str.appendSlice("$");
                } else {
                    const key = arg[index + 1 .. key_end];
                    index += key.len;

                    // if the environment variable does not exist write nothing
                    const val = self.env.getEnv(key) orelse continue;
                    try str.appendSlice(val);
                }
            } else {
                // if the character is not a part of any env variable lookup
                // then append it to the string
                try str.append(ch);
            }
        }

        return str.toOwnedSlice();
    }

    fn expandArguments(self: *Self, iter: *std.mem.TokenIterator(u8, .scalar)) std.mem.Allocator.Error!std.ArrayList([]const u8) {
        var args = std.ArrayList([]const u8).init(self.allocator);

        while (iter.next()) |part| {
            const val = try self.expandArgument(part);
            try args.append(val);
        }

        return args;
    }

    fn parseLine(self: *Self, line: []const u8) std.mem.Allocator.Error!std.ArrayList([]const u8) {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        return self.expandArguments(&iter);
    }

    fn findExec(self: *Self, name: []const u8) void {
        _ = self;
        _ = name;
    }

    fn handleExternal(self: *Self, cmd: []const u8, args: []const []const u8) !void {
        _ = self;
        _ = args;
        if (std.mem.startsWith(u8, cmd, "/")) {
            const fd = try rook.open(cmd);
            try rook.io.out.writer().print("opened {}\n", .{fd});
        }
    }

    const MAX_LINE_LEN = 4096;

    pub fn readLoop(self: *Self) noreturn {
        var line_buff: [MAX_LINE_LEN]u8 = undefined;
        var buff_stream = std.io.fixedBufferStream(&line_buff);

        const stdin_reader = rook.io.in.reader();
        while (true) : (buff_stream.reset()) {
            printPompt() catch {};
            stdin_reader.streamUntilDelimiter(buff_stream.writer(), '\n', MAX_LINE_LEN) catch @panic("Failed to read line from stdin");
            if (buff_stream.getPos() catch unreachable == 0) continue;
            self.handleLine(buff_stream.getWritten());
        }
    }
};

const PROMPT: []const u8 = "$ ";

fn printPompt() !void {
    _ = try rook.io.out.writeAll(PROMPT);
}

fn findNextNonAlphanumeric(str: []const u8, start_idx: usize) ?usize {
    var i = start_idx;
    while (i < str.len) : (i += 1)
        if (!std.ascii.isAlphanumeric(str[i])) return i;

    return null;
}

const std = @import("std");
const rook = @import("rook/rook.zig");
const command = @import("command.zig");
const env = @import("env.zig");

comptime {
    @export(rook._start, .{ .name = "_start" });
}

const PROMPT: []const u8 = "$ ";

pub fn print_prompt() !void {
    _ = try rook.io.out.writeAll(PROMPT);
}

pub fn main(args: []const [*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    try env.init_env(envp);
    _ = env;
    _ = args;

    var line_buff = std.ArrayList(u8).init(rook.page_allocator);
    defer line_buff.deinit();
    var line_buff_writer = line_buff.writer();

    const stdin_reader = rook.io.in.reader();
    while (true) : (line_buff.clearRetainingCapacity()) {
        try print_prompt();
        try stdin_reader.streamUntilDelimiter(line_buff_writer, '\n', null);

        try command.handle_line(rook.page_allocator, line_buff.items);
    }
}

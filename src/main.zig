const std = @import("std");
const rook = @import("rook/rook.zig");
const command = @import("command.zig");
const env = @import("env.zig");

comptime {
    @export(rook._start, .{ .name = "_start" });
}

const PROMPT: []const u8 = "$ ";
const MAX_LINE_LEN = 4096;

pub fn print_prompt() !void {
    _ = try rook.io.out.writeAll(PROMPT);
}

pub fn main(args: []const [*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    try env.init_env(envp);
    _ = args;

    var line_buff: [MAX_LINE_LEN]u8 = undefined;
    var buff_stream = std.io.fixedBufferStream(&line_buff);

    const stdin_reader = rook.io.in.reader();
    while (true) : (buff_stream.reset()) {
        try print_prompt();
        try stdin_reader.streamUntilDelimiter(buff_stream.writer(), '\n', MAX_LINE_LEN);
        try command.handle_line(rook.page_allocator, buff_stream.getWritten());
    }
}

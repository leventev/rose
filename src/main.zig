const std = @import("std");
const rook = @import("rook/rook.zig");
const command = @import("command.zig");

comptime {
    @export(rook._start, .{ .name = "_start" });
}

const PROMPT: []const u8 = "$ ";

pub fn print_prompt() !void {
    _ = try rook.io.out.write(PROMPT);
}

pub fn main(args: []const [*:0]const u8, env: [*:null]const ?[*:0]const u8) !void {
    _ = env;
    _ = args;

    var line_buff = std.ArrayList(u8).init(rook.page_allocator);
    var line_buff_writer = line_buff.writer();

    const stdin_reader = rook.io.in.reader();
    while (true) {
        try print_prompt();
        try stdin_reader.streamUntilDelimiter(line_buff_writer, '\n', null);

        try command.handle_line(line_buff.items);
        line_buff.items.len = 0;
    }
}

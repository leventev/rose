const rook = @import("rook/rook.zig");

pub fn builtin_echo(args: []const []const u8) !void {
    const writer = rook.io.out.writer();
    for (args) |arg| {
        try writer.print("{s} ", .{arg});
    }
    try writer.writeByte('\n');
}

pub fn builtin_pwd(_: []const []const u8) !void {
    const cwd = try rook.fd2path_alloc(rook.page_allocator, rook.CWD_FD);
    errdefer rook.page_allocator.free(cwd);
    const writer = rook.io.out.writer();
    try writer.print("{s}\n", .{cwd});
}

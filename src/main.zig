const std = @import("std");
const rook = @import("rook/rook.zig");
const Shell = @import("shell.zig").Shell;

comptime {
    @export(rook._start, .{ .name = "_start" });
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = ret_addr;
    _ = error_return_trace;
    const writer = rook.io.out.writer();
    writer.print("PANIC: {s}\n", .{msg}) catch {};
    while (true) {}
}

pub fn main(args: []const [*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    _ = args;
    var shell = try Shell.init(rook.page_allocator, envp);
    shell.read_loop();
}

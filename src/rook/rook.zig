const root = @import("root");
const syscall = @import("syscall.zig").syscall;
const err = @import("error.zig");
const std = @import("std");

const rook = @This();

const errno = err.errno;
pub const fd_t = isize;

pub const STDOUT_FILENO = 0;
pub const STDIN_FILENO = 1;
pub const STDERR_FILENO = 2;

pub const CWD_FD = 3;
pub const PATH_COMPONENT_MAX = 256;
pub const PATH_FULL_MAX = 4096;

pub fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\xorl %ebp, %ebp
        \\movq %rsp, %rdi
        \\andq $-16, %rsp
        \\call callMain
    );
}

export fn callMain(sp: [*]const usize) callconv(.C) noreturn {
    const argc = sp[0];
    const argv: [*]const [*:0]const u8 = @ptrCast(sp + 1);
    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(sp + argc + 2);
    root.main(argv[0..argc], envp) catch {};
    exit();
}

pub const stdio = struct {
    pub const in = 0;
    pub const out = 1;
    pub const err = 2;
};

pub const File = struct {
    fd: i32,
    pub fn read(this: File, buf: []u8) !usize {
        return rook.read(this.fd, buf);
    }
    pub fn write(this: File, buf: []const u8) !usize {
        return rook.write(this.fd, buf);
    }
    pub fn writeAll(this: File, buf: []const u8) !void {
        return rook.writeAll(this.fd, buf);
    }

    const Reader = std.io.Reader(File, ReadError, File.read);
    pub fn reader(this: File) Reader {
        return .{ .context = this };
    }
    const Writer = std.io.Writer(File, WriteError, File.write);
    pub fn writer(this: File) Writer {
        return .{ .context = this };
    }
};
pub const io = struct {
    pub const in = File{ .fd = stdio.in };
    pub const out = File{ .fd = stdio.out };
    pub const err = File{ .fd = stdio.err };
};

pub const WriteError = error{
    bad_file_descriptor,
};

pub fn write(fd: i32, buf: []const u8) WriteError!usize {
    const bytesWritten: isize = @bitCast(syscall(.write, .{ fd, buf.ptr, buf.len }));
    if (bytesWritten < 0) return switch (@as(errno, @enumFromInt(-bytesWritten))) {
        .BADF => WriteError.bad_file_descriptor,
        else => |e| err.panicUnexpectedErrno(e),
    };
    return @bitCast(bytesWritten);
}

pub fn exit() noreturn {
    @as(*allowzero volatile usize, @ptrFromInt(0)).* = 0;
    unreachable;
}

pub fn isatty(fd: fd_t) usize {
    // TODO: actual isatty implementation
    return @intFromBool(fd < 3);
}

/// Get the errno from a syscall return value, or 0 for no error.
pub fn getErrno(r: usize) errno {
    const signed_r = @as(isize, @bitCast(r));
    const int = if (signed_r > -4096 and signed_r < 0) -signed_r else 0;
    return @as(errno, @enumFromInt(int));
}

pub fn writeAll(fd: i32, buf: []const u8) !void {
    var bytesWritten: usize = 0;
    while (bytesWritten != buf.len) {
        bytesWritten += try write(fd, buf[bytesWritten..]);
    }
}

pub const ReadError = error{
    bad_file_descriptor,
};

pub fn read(fd: i32, buf: []u8) ReadError!usize {
    const bytesRead: isize = @bitCast(syscall(.read, .{ fd, buf.ptr, buf.len }));
    if (bytesRead < 0) return switch (@as(errno, @enumFromInt(-bytesRead))) {
        .BADF => ReadError.bad_file_descriptor,
        else => |e| err.panicUnexpectedErrno(e),
    };
    return @bitCast(bytesRead);
}

pub const MMapError = error{
    bad_file_descriptor,
    no_memory,
};

pub const MMapProt = packed struct(i32) {
    read: bool = false,
    write: bool = false,
    exec: bool = false,
    _pad0: u29 = 0,
};

pub const MMapFlags = packed struct(i32) {
    shared: bool = false,
    private: bool = false,
    shared_validate: bool = false,
    _pad0: u1 = 0,
    fixed: bool = false,
    anonymous: bool = false,
    _pad1: u26 = 0,
};

const FdToPathError = error{BufferTooSmall};

pub fn fd2path(fd: fd_t, buff: []u8) FdToPathError!usize {
    const bytes_written: isize = @bitCast(syscall(.fd2path, .{ fd, buff.ptr, buff.len }));
    if (bytes_written > -4096 and bytes_written < 0) return switch (@as(errno, @enumFromInt(-bytes_written))) {
        .INVAL => FdToPathError.BufferTooSmall,
        else => |e| err.panicUnexpectedErrno(e),
    };

    return @bitCast(bytes_written);
}

pub fn fd2path_alloc(allocator: std.mem.Allocator, fd: fd_t) ![]const u8 {
    var buff: [PATH_FULL_MAX]u8 = undefined;
    const written = try fd2path(fd, &buff);
    return allocator.dupe(u8, buff[0..written]);
}

const OpenError = error{NoSuchFileOrDirectory};
// TODO: flags, mode
pub fn open(path: []const u8) !fd_t {
    const dirfd: isize = if (std.mem.startsWith(u8, path, "/"))
        -1
    else
        CWD_FD;

    // TODO: errors
    const fd: isize = @bitCast(syscall(.openat, .{ dirfd, path.ptr, path.len, 0, 0 }));
    if (fd > -4096 and fd < 0) return switch (@as(errno, @enumFromInt(-fd))) {
        .NOENT => return OpenError.NoSuchFileOrDirectory,
        else => |e| err.panicUnexpectedErrno(e),
    };

    return @bitCast(fd);
}

pub fn mmap(
    addr: ?*anyopaque,
    length: usize,
    prot: MMapProt,
    flags: MMapFlags,
    fd: fd_t,
    offset: usize,
) MMapError![]align(4096) u8 {
    const result: isize = @bitCast(syscall(.mmap, .{ addr, length, prot, flags, fd, offset }));
    if (result > -4096 and result < 0) return switch (@as(errno, @enumFromInt(-result))) {
        .BADF => MMapError.bad_file_descriptor,
        .NOMEM => MMapError.no_memory,
        else => |e| err.panicUnexpectedErrno(e),
    };
    return @as([*]align(4096) u8, @ptrFromInt(@as(usize, @bitCast(result))))[0..length];
}

pub fn munmap(mem: []align(4096) u8) !void {
    const result: isize = @bitCast(syscall(.munmap, .{ mem.ptr, mem.len }));
    if (result > -4096 and result < 0) return switch (@as(errno, @enumFromInt(-result))) {
        else => |e| err.panicUnexpectedErrno(e),
    };
}

fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = ptr_align;
    _ = ret_addr;
    const aligned_len = std.mem.alignForward(usize, len, 4096);
    //const mem = mmap(
    //    null,
    //    aligned_len,
    //    .{ .read = true, .write = true },
    //    .{ .private = true, .anonymous = true },
    //    -1,
    //    0,
    //) catch return null;
    const mem = mmap(null, aligned_len, .{}, .{}, -1, 0) catch return null;
    return mem.ptr;
}

fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
    const aligned_len = std.mem.alignForward(usize, buf.len, 4096);
    _ = aligned_len;
    const new_ptr = alloc(ctx, new_len, buf_align, ret_addr);
    if (new_ptr == null) return false;
    for (buf, 0..) |c, i| new_ptr.?[i] = c;
    return true;
}

fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = ret_addr;
}

pub const page_allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};

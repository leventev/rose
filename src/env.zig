const std = @import("std");
const rook = @import("rook/rook.zig");

const default_envvars = .{
    .{ "PATH", "/bin:/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin" },
};

var envvars: std.StringHashMap([]const u8) = undefined;

const EnvPair = struct { key: []const u8, val: []const u8 };
fn parse_env_var(env: []const u8) ?EnvPair {
    // the length of an environment variable must be atleast 2
    // for example "a="
    if (env.len < 2) return null;

    const sep_idx = std.mem.indexOf(u8, env, "=") orelse return null;
    // the key of an env var can't be 0 sized
    if (sep_idx == 0) return null;

    return EnvPair{
        .key = env[0..sep_idx],
        .val = env[sep_idx + 1 .. env.len],
    };
}

pub fn init_env(envp: [*:null]const ?[*:0]const u8) !void {
    envvars = std.StringHashMap([]const u8).init(rook.page_allocator);

    // set default environment variables
    inline for (default_envvars) |env| {
        try envvars.put(env[0], env[1]);
    }

    // override or set environment variables
    var idx: usize = 0;
    while (envp[idx]) |env| : (idx += 1) {
        const env_str = std.mem.span(env);
        var e = parse_env_var(env_str) orelse continue;

        try envvars.put(e.key, e.val);
    }
}

pub fn get_env(key: []const u8) ?[]const u8 {
    return envvars.get(key);
}

pub fn set_env(key: []const u8, val: []const u8) !void {
    envvars.put(key, val);
}

pub fn get_env_iterator() !std.StringHashMap([]const u8).Iterator {
    return envvars.iterator();
}

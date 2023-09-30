const std = @import("std");
const rook = @import("rook/rook.zig");
const assert = std.debug.assert;

const DEFAULT_PATH = "/bin:/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin";

const default_envvars = .{
    .{ "PATH", DEFAULT_PATH },
};

const ParsePathVarError = error{IllegalPathValue} || std.mem.Allocator.Error;
fn parsePathVar(allocator: std.mem.Allocator, path: []const u8) ParsePathVarError!std.ArrayListUnmanaged([]const u8) {
    var new_path = std.ArrayListUnmanaged([]const u8){};
    errdefer {
        for (new_path.items) |str| {
            allocator.free(str);
        }
        new_path.deinit(allocator);
    }

    // TODO: define what a valid path looks like
    var iter = std.mem.split(u8, path, ":");
    while (iter.next()) |component| {
        var copied_str = try allocator.dupe(u8, component);
        try new_path.append(allocator, copied_str);
    }

    return new_path;
}

const EnvPair = struct { key: []const u8, val: []const u8 };
fn parseEnvVar(env: []const u8) ?EnvPair {
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

pub const Env = struct {
    const Self = Env;
    const EnvvarMap = std.StringArrayHashMapUnmanaged([]const u8);

    vars: EnvvarMap,
    path: std.ArrayListUnmanaged([]const u8),

    pub fn init(allocator: std.mem.Allocator, envp: [*:null]const ?[*:0]const u8) !Env {
        var env: Self = .{
            .vars = EnvvarMap{},
            .path = std.ArrayListUnmanaged([]const u8){},
        };

        // set default environment variables
        inline for (default_envvars) |envvar| {
            try env.setEnv(allocator, envvar[0], envvar[1]);
        }

        // override or set environment variables
        var idx: usize = 0;
        while (envp[idx]) |envvar| : (idx += 1) {
            const env_str = std.mem.span(envvar);
            const e = parseEnvVar(env_str) orelse continue;
            try env.setEnv(allocator, e.key, e.val);
        }

        // make sure $PATH is set
        assert(env.path.capacity > 0 and env.vars.get("PATH") != null);

        return env;
    }

    pub fn getEnv(self: *Env, key: []const u8) ?[]const u8 {
        return self.vars.get(key);
    }

    pub const SetEnvError = ParsePathVarError || std.mem.Allocator.Error;
    pub fn setEnv(self: *Self, allocator: std.mem.Allocator, key: []const u8, val: []const u8) SetEnvError!void {
        if (std.mem.eql(u8, key, "PATH")) {
            const new_path = try parsePathVar(allocator, val);
            for (self.path.items) |str| {
                allocator.free(str);
            }
            self.path.deinit(allocator);

            self.path = new_path;
        }

        const key_copied = try allocator.dupe(u8, key);
        const val_copied = try allocator.dupe(u8, val);

        try self.vars.put(allocator, key_copied, val_copied);
    }

    pub fn getEnvIterator(self: *Self) EnvvarMap.Iterator {
        return self.vars.iterator();
    }
};

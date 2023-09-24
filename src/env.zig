const std = @import("std");
const rook = @import("rook/rook.zig");

const default_envvars = .{
    .{ "PATH", "/bin:/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin" },
};

pub const Env = struct {
    const EnvvarMap = std.StringArrayHashMapUnmanaged([]const u8);

    allocator: std.mem.Allocator,
    vars: EnvvarMap,

    pub fn init(allocator: std.mem.Allocator, envp: [*:null]const ?[*:0]const u8) !Env {
        var vars = EnvvarMap{};

        // set default environment variables
        inline for (default_envvars) |env| {
            try vars.put(allocator, env[0], env[1]);
        }

        // override or set environment variables
        var idx: usize = 0;
        while (envp[idx]) |env| : (idx += 1) {
            const env_str = std.mem.span(env);
            var e = parse_env_var(env_str) orelse continue;

            try vars.put(allocator, e.key, e.val);
        }

        return .{
            .vars = vars,
            .allocator = allocator,
        };
    }

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

    pub fn get_env(self: *Env, key: []const u8) ?[]const u8 {
        return self.vars.get(key);
    }

    pub const SetEnvError = ParsePathVarError || std.mem.Allocator.Error;
    pub fn set_env(self: *Env, key: []const u8, val: []const u8) SetEnvError!void {
        if (std.mem.eql(u8, key, "PATH")) {
            try parse_path_var();
        }

        self.vars.put(key, val);
    }

    pub fn get_env_iterator(self: *Env) EnvvarMap.Iterator {
        return self.vars.iterator();
    }

    pub const ParsePathVarError = error{IllegalPathValue};
    fn parse_path_var(path: []const u8) ParsePathVarError!void {
        _ = path;
    }
};

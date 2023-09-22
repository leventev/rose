const syscall_no = enum(usize) {
    write = 0,
    read = 1,
    openat = 2,
    close = 3,
    fstatat = 4,
    mmap = 5,
    getpid = 6,
    getppid = 7,
    getuid = 8,
    geteuid = 9,
    getgid = 10,
    getegid = 11,
    fcntl = 12,
    ioctl = 13,
    getpgid = 14,
    setpgid = 15,
    clone = 16,
    execve = 17,
    lseek = 18,
    log = 19,
    arch_ctl = 20,
    gettimeofday = 21,
    pselect = 22,
    fd2path = 23,
};

pub inline fn syscall(sysno: syscall_no, args: anytype) usize {
    return switch (args.len) {
        0 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
            : "rcx", "r11", "memory"
        ),
        1 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
            : "rcx", "r11", "memory"
        ),
        2 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
            : "rcx", "r11", "memory"
        ),
        3 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
            : "rcx", "r11", "memory"
        ),
        4 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
            : "rcx", "r11", "memory"
        ),
        5 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
              [a4] "{r8}" (args[4]),
            : "rcx", "r11", "memory"
        ),
        6 => asm volatile ("int $0x80"
            : [ret] "={rax}" (-> usize),
            : [sysno] "{rax}" (sysno),
              [a0] "{rdi}" (args[0]),
              [a1] "{rsi}" (args[1]),
              [a2] "{rdx}" (args[2]),
              [a3] "{r10}" (args[3]),
              [a4] "{r8}" (args[4]),
              [a5] "{r9}" (args[5]),
            : "rcx", "r11", "memory"
        ),
        else => @compileError("Not implemented"),
    };
}

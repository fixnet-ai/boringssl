const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    // 将 zig target 映射为 cmake 系统名称和处理器
    const cmake_system = switch (target.result.os.tag) {
        .macos => "Darwin",
        .linux => "Linux",
        .windows => "Windows",
        else => @panic("unsupported target OS"),
    };

    const cmake_processor = switch (target.result.cpu.arch) {
        .aarch64 => if (target.result.os.tag == .windows) "ARM64" else "aarch64",
        else => @panic("unsupported CPU arch"),
    };

    const zig_target = b.fmt("{s}-{s}-{s}", .{
        @tagName(target.result.cpu.arch),
        @tagName(target.result.os.tag),
        switch (target.result.os.tag) {
            .linux => "musl",
            .windows => "gnu",
            else => "none",
        },
    });

    // 通过 shell 创建 zig-ar / zig-ranlib wrapper 脚本
    // cmake 要求 AR/RANLIB 是单可执行文件，不能用带空格子命令
    const setup_wrappers = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\ZIG="$(which zig 2>/dev/null || echo zig)"
            \\mkdir -p build/wrappers
            \\printf '#!/bin/sh\nexec %s ar "$@"\n' "$ZIG" > build/wrappers/zig-ar
            \\printf '#!/bin/sh\nexec %s ranlib "$@"\n' "$ZIG" > build/wrappers/zig-ranlib
            \\chmod +x build/wrappers/zig-ar build/wrappers/zig-ranlib
            \\# 跨平台交叉编译时 macOS target 需要 install_name_tool dummy
            \\test -x /usr/bin/true && ln -sf /usr/bin/true build/wrappers/install_name_tool 2>/dev/null || true
        , .{}),
    });

    // cmake 配置 - 注意 -D 参数需合并 =value 部分，否则 cmake 解析失败
    const zig_path = b.fmt("{s}/wrappers", .{"build"});
    const configure = b.addSystemCommand(&.{
        "cmake",
        "-B", "build",
        "-GNinja",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        b.fmt("-DCMAKE_SYSTEM_NAME={s}", .{cmake_system}),
        b.fmt("-DCMAKE_SYSTEM_PROCESSOR={s}", .{cmake_processor}),
        "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",
        "-DOPENSSL_NO_ASM=ON",
        b.fmt("-DCMAKE_AR={s}/zig-ar", .{zig_path}),
        b.fmt("-DCMAKE_RANLIB={s}/zig-ranlib", .{zig_path}),
        "-S", "src",
    });
    configure.step.dependOn(&setup_wrappers.step);
    configure.setEnvironmentVariable("CC", b.fmt("zig cc -target {s}", .{zig_target}));
    configure.setEnvironmentVariable("CXX", b.fmt("zig c++ -target {s}", .{zig_target}));
    configure.setEnvironmentVariable("GOWORK", "off");

    // cmake 构建
    const build_cmd = b.addSystemCommand(&.{
        "cmake", "--build", "build", "--target", "ssl", "crypto", "--config", "Release",
    });
    build_cmd.step.dependOn(&configure.step);
    build_cmd.setEnvironmentVariable("GOWORK", "off");

    // 收集产物到 zig-out/<target>/
    const out_dir = b.fmt("zig-out/{s}", .{zig_target});

    const copy_libs = b.addSystemCommand(&.{
        "sh", "-c",
        b.fmt(
            \\set -e
            \\mkdir -p "{0s}/lib" "{0s}/include"
            \\cp build/ssl/libssl.a "{0s}/lib/"
            \\cp build/crypto/libcrypto.a "{0s}/lib/"
            \\cp -R src/include/openssl "{0s}/include/"
            \\echo "Built: {0s}/"
        , .{out_dir}),
    });
    copy_libs.step.dependOn(&build_cmd.step);
    b.default_step.dependOn(&copy_libs.step);
}

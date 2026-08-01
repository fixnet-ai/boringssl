# BoringSSL Prebuilt

为 zigbox 全平台编译提供预构建的 BoringSSL 静态库。

三平台统一通过 `zig cc` 交叉编译，产物 ABI 完全一致。

## 支持平台

| 目标 | zig cc target | 产物 |
|------|--------------|------|
| `macos-aarch64` | `aarch64-macos-none` | `libssl.a` + `libcrypto.a` |
| `linux-aarch64` | `aarch64-linux-musl` | `libssl.a` + `libcrypto.a` |
| `windows-aarch64` | `aarch64-windows-gnu` | `libssl.a` + `libcrypto.a` |

## 使用方式

### 下载预编译库

```bash
# 从最新 Release 下载（替换 VERSION）
curl -LO "https://github.com/fixnet-ai/boringssl/releases/download/${VERSION}/boringssl-linux-aarch64.tar.gz"
tar xzf boringssl-linux-aarch64.tar.gz
```

产物结构：
```
boringssl-linux-aarch64/
├── include/
│   └── openssl/    ← 头文件
│       ├── ssl.h
│       ├── ...
└── lib/
    ├── libssl.a
    └── libcrypto.a
```

### 在 zigbox 中使用

下载对应平台的库，然后在 `build.zig` 中链接：

```zig
zigbox.root_module.addIncludePath(b.path("deps/boringssl/include"));
zigbox.root_module.addObjectFile(b.path("deps/boringssl/lib/libssl.a"));
zigbox.root_module.addObjectFile(b.path("deps/boringssl/lib/libcrypto.a"));
```

## 手动触发构建

1. 进入 Actions → "Build BoringSSL" → Run workflow
2. 输入版本号（如 `v1.0.0`）
3. CI 将构建所有平台并创建 GitHub Release

## BoringSSL 版本

BoringSSL 源码来自 [boringssl.googlesource.com](https://boringssl.googlesource.com/boringssl)，
commit 在 `.github/workflows/build.yml` 的 `BORINGSSL_COMMIT` 中指定。

更新版本：修改该 commit hash 后 push 即可触发全平台重新构建。

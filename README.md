# Official Claude Code Native Installation on Termux (Android aarch64)

This guide provides a reproducible method for installing the official **Claude Code** (Anthropic CLI) on Termux. It uses the `glibc` repository to run the native Linux binary, bypassing the "Unsupported platform" error.

## Prerequisites

1. **Termux**: F-Droid or GitHub version.
2. **Architecture**: `aarch64` (verify with `uname -m`).
3. **Storage Access**: Run `termux-setup-storage`.

## Step 1: Install System Dependencies

```bash
pkg update && pkg upgrade -y
pkg install nodejs git binutils file tur-repo glibc-repo -y
pkg update
pkg install glibc -y
```

## Step 2: Install Claude Code Packages

We install the main CLI package and force-install the native `linux-arm64` binary.

```bash
# Main wrapper package
npm install -g @anthropic-ai/claude-code

# Official native aarch64 binary (force-installed for Android)
npm install -g @anthropic-ai/claude-code-linux-arm64 --force
```
## Step 3: Create the Native Wrapper

Instead of moving binaries, we create a direct wrapper script that uses the `glibc` runner (`grun`) to execute the native binary. Use `/bin/sh` with absolute paths to avoid shell initialization issues. We also clear `LD_PRELOAD` to prevent conflicts with Termux's internal libraries.

```bash
# Create the wrapper with absolute paths and clear LD_PRELOAD
cat <<'EOF' > /data/data/com.termux/files/usr/bin/claude
#!/bin/sh
# Clear LD_PRELOAD to avoid conflicts between Termux and glibc libraries
export LD_PRELOAD=
exec /data/data/com.termux/files/usr/glibc/bin/grun /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code-linux-arm64/claude "$@"
EOF

# Make executable
chmod +x /data/data/com.termux/files/usr/bin/claude
```

## Step 4: Fix glibc Environment (If needed)

If you encounter `invalid ELF header` errors, replace the ASCII linker scripts with symbolic links:

```bash
# Fix linker script issues
ln -sf /data/data/com.termux/files/usr/glibc/lib/libc.so.6 /data/data/com.termux/files/usr/glibc/lib/libc.so
ln -sf /data/data/com.termux/files/usr/glibc/lib/libm.so.6 /data/data/com.termux/files/usr/glibc/lib/libm.so
```

## Step 5: Verification
**Note:** Do not use bash in the shebang or variable expansion—new shell sessions may have glibc initialization issues. The absolute path approach is more robust.

## Step 4: Verification

```bash
claude --version
```
Expected output: `2.x.x (Claude Code)`

## Why this works
- **glibc-repo**: Provides a standard Linux C library environment within Termux.
- **grun**: A loader that runs glibc-linked binaries using the libraries in `/usr/glibc`.
- **--force**: Bypasses the `npm` platform check that usually blocks "linux" packages on "android".

---
*Verified and updated on May 6, 2026.*
*Wrapper revised to use `/bin/sh` with absolute paths for robustness.*

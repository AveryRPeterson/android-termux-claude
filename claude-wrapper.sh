#!/bin/sh
# Clear LD_PRELOAD to avoid conflicts between Termux and glibc libraries
export LD_PRELOAD=
exec /data/data/com.termux/files/usr/glibc/bin/grun /data/data/com.termux/files/usr/lib/node_modules/@anthropic-ai/claude-code-linux-arm64/claude "$@"

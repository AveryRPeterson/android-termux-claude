#!/bin/sh
# install.sh — Automated Claude Code installer for Termux (Android aarch64)
# Usage: ./install.sh [--dry-run] [--repair]

set -e

TERMUX_PREFIX=/data/data/com.termux/files/usr
GLIBC_BIN=$TERMUX_PREFIX/glibc/bin/grun
NODE_MODULES=$TERMUX_PREFIX/lib/node_modules
WRAPPER=$TERMUX_PREFIX/bin/claude
ARM64_BIN=$NODE_MODULES/@anthropic-ai/claude-code-linux-arm64/claude

DRY_RUN=0
REPAIR=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --repair)  REPAIR=1 ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--repair]"
      echo ""
      echo "  --dry-run   Print commands without executing them"
      echo "  --repair    Run the glibc repair procedure instead of a fresh install"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

# ── helpers ──────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
error() { printf "${RED}[x]${RESET} %s\n" "$*" >&2; }
step()  { printf "\n${GREEN}══ Step %s ══${RESET}\n" "$*"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "${YELLOW}[dry-run]${RESET} %s\n" "$*"
  else
    eval "$*"
  fi
}

# ── pre-flight checks ─────────────────────────────────────────────────────────

check_prerequisites() {
  step "0: Pre-flight checks"

  ARCH=$(uname -m)
  if [ "$ARCH" != "aarch64" ]; then
    error "This script targets aarch64 (Android ARM64). Detected: $ARCH"
    if [ "$DRY_RUN" -eq 0 ]; then
      exit 1
    else
      warn "Continuing in dry-run mode despite arch mismatch."
    fi
  else
    info "Architecture: $ARCH — OK"
  fi

  if ! command -v pkg > /dev/null 2>&1; then
    error "'pkg' not found. Are you running inside Termux?"
    if [ "$DRY_RUN" -eq 0 ]; then
      exit 1
    else
      warn "Continuing in dry-run mode without pkg."
    fi
  else
    info "Termux pkg: found — OK"
  fi

  if ! command -v npm > /dev/null 2>&1; then
    warn "npm not found — will be installed via pkg in Step 1."
  else
    info "npm: $(npm --version) — OK"
  fi
}

# ── repair ────────────────────────────────────────────────────────────────────

repair() {
  step "Repair: Reset glibc environment"
  warn "This will uninstall glibc and glibc-repo, then reinstall from scratch."

  info "Uninstalling glibc and glibc-repo..."
  run "pkg uninstall -y glibc glibc-repo"
  run "pkg clean"

  info "Reinstalling glibc-repo and glibc..."
  run "pkg update"
  run "pkg install -y glibc-repo"
  run "pkg install -y glibc"

  step "Repair: Restore wrapper script"
  write_wrapper

  step "Repair: Verify"
  verify
}

# ── fresh install ─────────────────────────────────────────────────────────────

install_system_deps() {
  step "1: Install system dependencies"
  run "pkg update && pkg upgrade -y"
  run "pkg install -y nodejs git binutils file tur-repo glibc-repo"
  run "pkg update"
  run "pkg install -y glibc"
  info "System dependencies installed."
}

install_npm_packages() {
  step "2: Install Claude Code npm packages"
  info "Installing @anthropic-ai/claude-code..."
  run "npm install -g @anthropic-ai/claude-code"
  info "Force-installing native linux-arm64 binary..."
  run "npm install -g @anthropic-ai/claude-code-linux-arm64 --force"
  info "npm packages installed."
}

fix_glibc_linker() {
  step "3b: Fix glibc linker scripts (symlinks)"
  info "Replacing ASCII linker scripts with symlinks..."
  run "ln -sf ${TERMUX_PREFIX}/glibc/lib/libc.so.6 ${TERMUX_PREFIX}/glibc/lib/libc.so"
  run "ln -sf ${TERMUX_PREFIX}/glibc/lib/libm.so.6 ${TERMUX_PREFIX}/glibc/lib/libm.so"
  info "Linker symlinks created."
}

write_wrapper() {
  step "3a: Create native wrapper script"
  info "Writing wrapper to $WRAPPER..."
  run "cat <<'WRAPPER_EOF' > $WRAPPER
#!/bin/sh
export LD_PRELOAD=
exec $GLIBC_BIN $ARM64_BIN \"\$@\"
WRAPPER_EOF"
  run "chmod +x $WRAPPER"
  info "Wrapper created: $WRAPPER"
}

verify() {
  step "4: Verify installation"
  info "Running: claude --version"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "${YELLOW}[dry-run]${RESET} claude --version\n"
  else
    claude --version && info "Claude Code installed successfully!" || {
      error "Verification failed. Try running with --repair, or check the README for manual steps."
      exit 1
    }
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN mode: no commands will be executed."
fi

check_prerequisites

if [ "$REPAIR" -eq 1 ]; then
  repair
else
  install_system_deps
  install_npm_packages
  write_wrapper
  fix_glibc_linker
  verify
fi

info "Done."

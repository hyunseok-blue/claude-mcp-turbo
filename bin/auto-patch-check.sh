#!/bin/bash
# auto-patch-check.sh - Lightweight patch check for SessionStart hook
# Checks if OMC needs patching and auto-applies if necessary
# Designed to be near-zero cost when already patched

OMC_CACHE="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"
LATEST=$(ls -1d "$OMC_CACHE"/*/ 2>/dev/null | sort -V | tail -1)
[ -z "$LATEST" ] && exit 0

BRIDGE="${LATEST%/}/bridge/codex-server.cjs"
[ ! -f "$BRIDGE" ] && exit 0

# Already patched — fast exit
grep -q 'rate\[- \]limit' "$BRIDGE" 2>/dev/null && exit 0

# Patch needed — auto-apply
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/patch-omc.sh"

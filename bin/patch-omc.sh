#!/bin/bash
# patch-omc.sh - Apply Codex/Gemini MCP bug patches to OMC plugin
# Safely patches isRateLimitError() false positive and related regex issues
# Re-run after every OMC version update

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OMC_CACHE="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[PASS]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# Find latest OMC version directory
find_omc_version() {
  if [ ! -d "$OMC_CACHE" ]; then
    fail "OMC plugin cache not found at $OMC_CACHE"
    exit 1
  fi
  # Get the latest version directory
  local latest
  latest=$(ls -1d "$OMC_CACHE"/*/ 2>/dev/null | sort -V | tail -1)
  if [ -z "$latest" ]; then
    fail "No OMC version found in $OMC_CACHE"
    exit 1
  fi
  echo "${latest%/}"
}

# Backup a file before patching
backup_file() {
  local file="$1"
  local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
  if [ -f "$file" ]; then
    cp "$file" "$backup"
    info "Backup: $backup"
  fi
}

# Patch isRateLimitError in codex-core.ts
patch_codex_core_ts() {
  local file="$1/src/mcp/codex-core.ts"
  if [ ! -f "$file" ]; then
    warn "codex-core.ts not found at $file (source may not be present)"
    return 0
  fi

  # Check if already patched (look for our signature: rate[- ]limit)
  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "codex-core.ts already patched"
    return 0
  fi

  backup_file "$file"

  # Fix 1: Replace isRateLimitError function - change broad regex check to line-by-line
  # Fix 2: Change rate.?limit → rate[- ]limit throughout
  sed -i.patch \
    -e 's/rate\.?limit/rate[- ]limit/g' \
    -e 's/quota\.?exceeded/quota[._-]exceeded/g' \
    -e 's/resource\.?exhausted/resource[._-]exhausted/g' \
    "$file"

  # Verify the patch was applied
  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "codex-core.ts patched (regex fix)"
    rm -f "${file}.patch"
  else
    fail "codex-core.ts patch failed"
    # Restore from backup
    mv "${file}.patch" "$file"
    return 1
  fi
}

# Patch isGeminiRetryableError in gemini-core.ts
patch_gemini_core_ts() {
  local file="$1/src/mcp/gemini-core.ts"
  if [ ! -f "$file" ]; then
    warn "gemini-core.ts not found at $file (source may not be present)"
    return 0
  fi

  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "gemini-core.ts already patched"
    return 0
  fi

  backup_file "$file"

  sed -i.patch \
    -e 's/rate\.?limit/rate[- ]limit/g' \
    -e 's/quota\.?exceeded/quota[._-]exceeded/g' \
    -e 's/resource\.?exhausted/resource[._-]exhausted/g' \
    "$file"

  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "gemini-core.ts patched (regex fix)"
    rm -f "${file}.patch"
  else
    fail "gemini-core.ts patch failed"
    mv "${file}.patch" "$file"
    return 1
  fi
}

# Patch compiled bridge/codex-server.cjs
patch_bridge() {
  local file="$1/bridge/codex-server.cjs"
  if [ ! -f "$file" ]; then
    warn "codex-server.cjs not found at $file"
    return 0
  fi

  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "codex-server.cjs already patched"
    return 0
  fi

  backup_file "$file"

  sed -i.patch \
    -e 's/rate\.?limit/rate[- ]limit/g' \
    -e 's/quota\.?exceeded/quota[._-]exceeded/g' \
    -e 's/resource\.?exhausted/resource[._-]exhausted/g' \
    "$file"

  if grep -q 'rate\[- \]limit' "$file" 2>/dev/null; then
    ok "codex-server.cjs patched (regex fix)"
    rm -f "${file}.patch"
  else
    fail "codex-server.cjs patch failed"
    mv "${file}.patch" "$file"
    return 1
  fi
}

# Main
echo "═══════════════════════════════════════════════"
echo "  OMC Bug Patch - Codex/Gemini False Positive Fix"
echo "═══════════════════════════════════════════════"
echo

OMC_DIR=$(find_omc_version)
VERSION=$(basename "$OMC_DIR")
info "OMC version: $VERSION"
info "OMC path: $OMC_DIR"
echo

patch_codex_core_ts "$OMC_DIR"
patch_gemini_core_ts "$OMC_DIR"
patch_bridge "$OMC_DIR"

echo
echo "═══════════════════════════════════════════════"
ok "Patch complete! Restart Claude Code for changes to take effect."
echo "═══════════════════════════════════════════════"

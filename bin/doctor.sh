#!/bin/bash
# doctor.sh - Codex/Gemini MCP Health Diagnostic
# Checks CLI installation, auth, config, patches, and connectivity

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC}  $*"; }
warn() { echo -e "  ${YELLOW}WARN${NC}  $*"; }
fail() { echo -e "  ${RED}FAIL${NC}  $*"; }
info() { echo -e "  ${BLUE}INFO${NC}  $*"; }

PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0

check_pass() { ((PASS_COUNT++)); pass "$@"; }
check_warn() { ((WARN_COUNT++)); warn "$@"; }
check_fail() { ((FAIL_COUNT++)); fail "$@"; }

echo "═══════════════════════════════════════════════════"
echo "  MCP Turbo Doctor - Health Diagnostic"
echo "═══════════════════════════════════════════════════"
echo

# ─── 1. Codex CLI ────────────────────────────────
echo -e "${CYAN}[1/9] Codex CLI${NC}"
if command -v codex &>/dev/null; then
  CODEX_VER=$(codex --version 2>/dev/null || echo "unknown")
  check_pass "Codex CLI installed ($CODEX_VER)"
else
  check_fail "Codex CLI not found (npm install -g @openai/codex)"
fi

# ─── 2. Gemini CLI ───────────────────────────────
echo -e "${CYAN}[2/9] Gemini CLI${NC}"
if command -v gemini &>/dev/null; then
  check_pass "Gemini CLI installed"
else
  check_fail "Gemini CLI not found (npm install -g @google/gemini-cli)"
fi

# ─── 3. OMC Plugin ───────────────────────────────
echo -e "${CYAN}[3/9] OMC Plugin${NC}"
OMC_CACHE="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"
if [ -d "$OMC_CACHE" ]; then
  OMC_VER=$(ls -1d "$OMC_CACHE"/*/ 2>/dev/null | sort -V | tail -1 | xargs basename)
  check_pass "OMC plugin v$OMC_VER"

  OMC_DIR="$OMC_CACHE/$OMC_VER"
  if [ -f "$OMC_DIR/bridge/codex-server.cjs" ]; then
    check_pass "Codex bridge exists"
  else
    check_fail "Codex bridge missing"
  fi
else
  check_fail "OMC plugin not found"
fi

# ─── 4. Environment Variables ────────────────────
echo -e "${CYAN}[4/9] Environment Variables${NC}"
check_env() {
  local var="$1" expected="$2"
  local val="${!var:-}"
  if [ -n "$val" ]; then
    if [ "$val" = "$expected" ]; then
      check_pass "$var=$val"
    else
      check_warn "$var=$val (expected: $expected)"
    fi
  else
    check_warn "$var not set (recommended: $expected)"
  fi
}

check_env "OMC_CODEX_DEFAULT_MODEL" "gpt-5.3-codex"
check_env "OMC_CODEX_RATE_LIMIT_RETRY_COUNT" "7"
check_env "OMC_CODEX_RATE_LIMIT_INITIAL_DELAY" "2000"
check_env "OMC_GEMINI_DEFAULT_MODEL" "gemini-3-pro-preview"

# ─── 5. .omc-config.json ────────────────────────
echo -e "${CYAN}[5/9] OMC Config${NC}"
OMC_CONFIG="$HOME/.claude/.omc-config.json"
if [ -f "$OMC_CONFIG" ]; then
  if grep -q '"useMcp": true' "$OMC_CONFIG" 2>/dev/null; then
    check_pass "useMcp: true"
  else
    check_fail "useMcp is not true in $OMC_CONFIG"
  fi

  if grep -q '"externalModels"' "$OMC_CONFIG" 2>/dev/null; then
    check_pass "externalModels configured"
  else
    check_warn "externalModels not configured (role routing disabled)"
  fi
else
  check_fail "$OMC_CONFIG not found"
fi

# ─── 6. Codex Test Call ──────────────────────────
echo -e "${CYAN}[6/9] Codex Connectivity${NC}"
if command -v codex &>/dev/null; then
  # Run codex test with bash-native timeout (works on macOS)
  CODEX_RESULT=""
  CODEX_RESULT=$(bash -c 'echo "Reply with just: OK" | codex exec -m gpt-5.3-codex --json --full-auto 2>/dev/null' &
    CODEX_PID=$!
    sleep 20 && kill $CODEX_PID 2>/dev/null &
    TIMER_PID=$!
    wait $CODEX_PID 2>/dev/null
    kill $TIMER_PID 2>/dev/null
  ) 2>/dev/null
  if echo "$CODEX_RESULT" | grep -q '"type"'; then
    check_pass "Codex API responding"
  else
    check_warn "Codex API test inconclusive (may need longer timeout)"
  fi
else
  info "Skipped (Codex CLI not installed)"
fi

# ─── 7. Patch Status ────────────────────────────
echo -e "${CYAN}[7/9] Patch Status${NC}"
if [ -n "${OMC_DIR:-}" ] && [ -d "${OMC_DIR:-}" ]; then
  # Check codex-core.ts
  CODEX_SRC="$OMC_DIR/src/mcp/codex-core.ts"
  if [ -f "$CODEX_SRC" ]; then
    if grep -q 'rate\[- \]limit' "$CODEX_SRC" 2>/dev/null; then
      check_pass "codex-core.ts patched"
    else
      check_fail "codex-core.ts NOT patched (run: bin/patch-omc.sh)"
    fi
  fi

  # Check gemini-core.ts
  GEMINI_SRC="$OMC_DIR/src/mcp/gemini-core.ts"
  if [ -f "$GEMINI_SRC" ]; then
    if grep -q 'rate\[- \]limit' "$GEMINI_SRC" 2>/dev/null; then
      check_pass "gemini-core.ts patched"
    else
      check_fail "gemini-core.ts NOT patched (run: bin/patch-omc.sh)"
    fi
  fi

  # Check bridge
  BRIDGE="$OMC_DIR/bridge/codex-server.cjs"
  if [ -f "$BRIDGE" ]; then
    if grep -q 'rate\[- \]limit' "$BRIDGE" 2>/dev/null; then
      check_pass "codex-server.cjs patched"
    else
      check_fail "codex-server.cjs NOT patched (run: bin/patch-omc.sh)"
    fi
  fi
else
  info "Skipped (OMC plugin not found)"
fi

# ─── 8. CLAUDE.md MCP-First Policy ──────────────
echo -e "${CYAN}[8/9] CLAUDE.md MCP-First Policy${NC}"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if grep -q 'mcp_first_policy' "$CLAUDE_MD" 2>/dev/null; then
    check_pass "MCP-first policy active in CLAUDE.md"
  else
    check_warn "MCP-first policy not found in CLAUDE.md"
  fi
else
  check_fail "CLAUDE.md not found"
fi

# ─── 9. Auto-Patch Hook ─────────────────────────
echo -e "${CYAN}[9/9] Auto-Patch Hook${NC}"
SETTINGS_JSON="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_JSON" ]; then
  if grep -q 'auto-patch-check' "$SETTINGS_JSON" 2>/dev/null; then
    check_pass "Auto-patch hook registered in settings.json"
  else
    check_warn "Auto-patch hook not registered (run: bin/setup.sh)"
  fi
else
  check_warn "settings.json not found (auto-patch hook not registered)"
fi

# ─── Summary ─────────────────────────────────────
echo
echo "═══════════════════════════════════════════════════"
echo -e "  ${GREEN}PASS: $PASS_COUNT${NC}  ${YELLOW}WARN: $WARN_COUNT${NC}  ${RED}FAIL: $FAIL_COUNT${NC}"

if [ $FAIL_COUNT -eq 0 ] && [ $WARN_COUNT -eq 0 ]; then
  echo -e "  ${GREEN}All checks passed! MCP Turbo is fully operational.${NC}"
elif [ $FAIL_COUNT -eq 0 ]; then
  echo -e "  ${YELLOW}Working with warnings. Review WARN items above.${NC}"
else
  echo -e "  ${RED}Issues found. Run: ~/claude-mcp-turbo/bin/setup.sh${NC}"
fi
echo "═══════════════════════════════════════════════════"

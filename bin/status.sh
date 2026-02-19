#!/bin/bash
# status.sh - MCP Usage Status Dashboard
# Shows rate limits, call counts, recent errors, and active workers

set -uo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'

echo "═══════════════════════════════════════════════════"
echo "  MCP Turbo Status Dashboard"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "═══════════════════════════════════════════════════"
echo

# ─── Environment ─────────────────────────────────
echo -e "${CYAN}Environment${NC}"
echo "  Codex Model:  ${OMC_CODEX_DEFAULT_MODEL:-gpt-5.3-codex}"
echo "  Gemini Model: ${OMC_GEMINI_DEFAULT_MODEL:-gemini-3-pro-preview}"
echo "  Retry Count:  ${OMC_CODEX_RATE_LIMIT_RETRY_COUNT:-3}"
echo "  Timeout:      ${OMC_CODEX_TIMEOUT:-3600000}ms"
echo

# ─── MCP Call Counts ─────────────────────────────
echo -e "${CYAN}MCP Call Counts (recent prompts)${NC}"

# Count prompt files in .omc directories
count_prompts() {
  local provider="$1"
  local count=0
  # Search common project directories for .omc/prompts
  for dir in "$HOME"/Documents/git/*/.omc/prompts "$HOME"/.omc/prompts; do
    if [ -d "$dir" ]; then
      local c
      c=$(find "$dir" -name "${provider}-*" -mtime -1 2>/dev/null | wc -l | tr -d ' ')
      count=$((count + c))
    fi
  done
  echo "$count"
}

CODEX_COUNT=$(count_prompts "codex")
GEMINI_COUNT=$(count_prompts "gemini")
C7_COUNT=$(count_prompts "context7")

echo "  Last 24h:"
echo "    Codex:    $CODEX_COUNT calls"
echo "    Gemini:   $GEMINI_COUNT calls"
echo "    Context7: $C7_COUNT calls"
echo

# ─── Recent Errors ───────────────────────────────
echo -e "${CYAN}Recent Errors (last 5)${NC}"
FOUND_ERRORS=0
for dir in "$HOME"/Documents/git/*/.omc/prompts "$HOME"/.omc/prompts; do
  if [ -d "$dir" ]; then
    for status_file in $(find "$dir" -name "*-status.json" -mmin -60 2>/dev/null | head -5); do
      if grep -q '"status": "failed"' "$status_file" 2>/dev/null; then
        local_error=$(python3 -c "
import json, sys
try:
    with open('$status_file') as f: d = json.load(f)
    print(f\"  {d.get('provider','?')} | {d.get('agentRole','?')} | {d.get('error','unknown')[:80]}\")
except: pass
" 2>/dev/null)
        if [ -n "$local_error" ]; then
          echo "$local_error"
          FOUND_ERRORS=$((FOUND_ERRORS + 1))
        fi
      fi
    done
  fi
done
if [ $FOUND_ERRORS -eq 0 ]; then
  echo -e "  ${GREEN}No recent errors${NC}"
fi
echo

# ─── Active Team/Workers ─────────────────────────
echo -e "${CYAN}Active Teams${NC}"
TEAM_DIR="$HOME/.claude/teams"
if [ -d "$TEAM_DIR" ] && [ "$(ls -A "$TEAM_DIR" 2>/dev/null)" ]; then
  for team_config in "$TEAM_DIR"/*/config.json; do
    if [ -f "$team_config" ]; then
      TEAM_NAME=$(basename "$(dirname "$team_config")")
      MEMBER_COUNT=$(python3 -c "
import json
try:
    with open('$team_config') as f: d = json.load(f)
    print(len(d.get('members', [])))
except: print('?')
" 2>/dev/null)
      echo "  $TEAM_NAME ($MEMBER_COUNT members)"
    fi
  done
else
  echo -e "  ${DIM}No active teams${NC}"
fi
echo

# ─── Patch Status ────────────────────────────────
echo -e "${CYAN}Patch Status${NC}"
OMC_CACHE="$HOME/.claude/plugins/cache/omc/oh-my-claudecode"
if [ -d "$OMC_CACHE" ]; then
  OMC_DIR=$(ls -1d "$OMC_CACHE"/*/ 2>/dev/null | sort -V | tail -1)
  OMC_DIR="${OMC_DIR%/}"
  VERSION=$(basename "$OMC_DIR")
  echo "  OMC Version: $VERSION"

  BRIDGE="$OMC_DIR/bridge/codex-server.cjs"
  if [ -f "$BRIDGE" ] && grep -q 'rate\[- \]limit' "$BRIDGE" 2>/dev/null; then
    echo -e "  Patches: ${GREEN}Applied${NC}"
  else
    echo -e "  Patches: ${RED}NOT Applied${NC} (run bin/patch-omc.sh)"
  fi
fi

echo
echo "═══════════════════════════════════════════════════"

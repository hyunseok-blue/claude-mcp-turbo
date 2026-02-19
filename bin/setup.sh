#!/bin/bash
# setup.sh - One-command MCP Turbo setup
# Runs: diagnose → configure → patch → verify

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo "═══════════════════════════════════════════════════"
echo "  Claude MCP Turbo - One-Command Setup"
echo "═══════════════════════════════════════════════════"
echo

# ─── Step 1: Environment Variables ───────────────
echo -e "${BLUE}[1/6] Setting up environment variables...${NC}"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source ~/claude-mcp-turbo/config/env.sh 2>/dev/null"
if grep -q "claude-mcp-turbo/config/env.sh" "$ZSHRC" 2>/dev/null; then
  ok "env.sh already sourced in .zshrc"
else
  echo "" >> "$ZSHRC"
  echo "# Claude MCP Turbo - Codex/Gemini 환경변수 (Pro Max 최적화)" >> "$ZSHRC"
  echo "$SOURCE_LINE" >> "$ZSHRC"
  ok "Added env.sh to .zshrc"
fi
# Source for current session
source "$REPO_DIR/config/env.sh"
ok "Environment variables loaded"

# ─── Step 2: .omc-config.json ───────────────────
echo -e "${BLUE}[2/6] Updating .omc-config.json...${NC}"
OMC_CONFIG="$HOME/.claude/.omc-config.json"
if [ -f "$OMC_CONFIG" ]; then
  # Check if already configured
  if grep -q '"useMcp": true' "$OMC_CONFIG" && grep -q '"externalModels"' "$OMC_CONFIG"; then
    ok ".omc-config.json already configured"
  else
    # Backup existing
    cp "$OMC_CONFIG" "${OMC_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    # Merge using python (jq alternative)
    python3 -c "
import json, sys
with open('$OMC_CONFIG') as f: config = json.load(f)
with open('$REPO_DIR/config/omc-config.patch.json') as f: patch = json.load(f)
for key, value in patch.items():
    if isinstance(value, dict) and isinstance(config.get(key), dict):
        config[key].update(value)
    else:
        config[key] = value
config['configuredAt'] = '$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'
with open('$OMC_CONFIG', 'w') as f: json.dump(config, f, indent=2)
print('done')
" && ok ".omc-config.json updated" || warn "Failed to update .omc-config.json (manual edit needed)"
  fi
else
  warn ".omc-config.json not found. Run OMC setup first: /oh-my-claudecode:omc-setup"
fi

# ─── Step 3: CLAUDE.md MCP-First Policy ─────────
echo -e "${BLUE}[3/6] Checking CLAUDE.md MCP-first policy...${NC}"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if grep -q 'mcp_first_policy' "$CLAUDE_MD"; then
    ok "MCP-first policy already in CLAUDE.md"
  else
    # Insert after </mcp_routing>
    PATCH_CONTENT=$(cat "$REPO_DIR/config/claude-md-patch.md")
    if grep -q '</mcp_routing>' "$CLAUDE_MD"; then
      sed -i.bak "/<\/mcp_routing>/r $REPO_DIR/config/claude-md-patch.md" "$CLAUDE_MD"
      ok "MCP-first policy added to CLAUDE.md"
    else
      warn "Could not find </mcp_routing> in CLAUDE.md. Add manually from config/claude-md-patch.md"
    fi
  fi
else
  warn "CLAUDE.md not found"
fi

# ─── Step 4: Apply OMC Patches ──────────────────
echo -e "${BLUE}[4/6] Applying OMC bug patches...${NC}"
bash "$SCRIPT_DIR/patch-omc.sh"

# ─── Step 5: Register Auto-Patch Hook ────────────
echo -e "${BLUE}[5/6] Registering auto-patch SessionStart hook...${NC}"
chmod +x "$SCRIPT_DIR/auto-patch-check.sh"
SETTINGS_JSON="$HOME/.claude/settings.json"
HOOK_CMD="$HOME/claude-mcp-turbo/bin/auto-patch-check.sh"

if [ -f "$SETTINGS_JSON" ]; then
  if grep -q 'auto-patch-check' "$SETTINGS_JSON" 2>/dev/null; then
    ok "Auto-patch hook already registered"
  else
    python3 -c "
import json, os, sys

settings_path = os.path.expanduser('$SETTINGS_JSON')
with open(settings_path) as f:
    settings = json.load(f)

# Ensure hooks.SessionStart exists
hooks = settings.setdefault('hooks', {})
session_start = hooks.setdefault('SessionStart', [])

# Add auto-patch-check hook
session_start.append({
    'type': 'command',
    'command': '$HOOK_CMD'
})

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
print('done')
" && ok "Auto-patch hook registered in settings.json" || warn "Failed to register hook (add manually)"
  fi
else
  # Create settings.json with the hook
  python3 -c "
import json
settings = {
    'hooks': {
        'SessionStart': [{
            'type': 'command',
            'command': '$HOOK_CMD'
        }]
    }
}
with open('$SETTINGS_JSON', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
print('done')
" && ok "Created settings.json with auto-patch hook" || warn "Failed to create settings.json"
fi

# ─── Step 6: Verify ─────────────────────────────
echo
echo -e "${BLUE}[6/6] Running diagnostics...${NC}"
echo
bash "$SCRIPT_DIR/doctor.sh"

echo
ok "Setup complete! Restart Claude Code to apply all changes."
echo "  Run 'source ~/.zshrc' to load env vars in current shell."

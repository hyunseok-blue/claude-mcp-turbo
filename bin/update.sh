#!/bin/bash
# update.sh - Update MCP Turbo settings
# Re-applies config and patches without full setup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }

echo "═══════════════════════════════════════════════════"
echo "  MCP Turbo - Quick Update"
echo "═══════════════════════════════════════════════════"
echo

# Reload env vars
info "Reloading environment variables..."
source "$REPO_DIR/config/env.sh"
ok "Environment variables loaded"

# Re-apply patches (idempotent)
info "Checking patches..."
bash "$SCRIPT_DIR/patch-omc.sh"

# Verify
echo
info "Running quick check..."
bash "$SCRIPT_DIR/doctor.sh"

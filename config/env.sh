#!/bin/bash
# Claude MCP Turbo - Environment Variables
# Codex Pro Max ($200/month) optimized settings
# Source this file in ~/.zshrc: source ~/claude-mcp-turbo/config/env.sh

# ═══════════════════════════════════════════════════
# Codex Pro Max - Aggressive settings (high rate limit)
# ═══════════════════════════════════════════════════
export OMC_CODEX_RATE_LIMIT_RETRY_COUNT=7        # Max retries on 429 (default: 3)
export OMC_CODEX_RATE_LIMIT_INITIAL_DELAY=2000    # Initial backoff 2s (default: 5s)
export OMC_CODEX_RATE_LIMIT_MAX_DELAY=60000       # Max backoff 60s (default: 60s)
export OMC_CODEX_DEFAULT_MODEL=gpt-5.3-codex      # Default model
export OMC_CODEX_TIMEOUT=600000                    # 10 minute timeout (default: 3600s)

# ═══════════════════════════════════════════════════
# Gemini Settings
# ═══════════════════════════════════════════════════
export OMC_GEMINI_DEFAULT_MODEL=gemini-3-pro-preview  # Default model
export OMC_GEMINI_TIMEOUT=600000                       # 10 minute timeout

# ═══════════════════════════════════════════════════
# Optional: Allow working directory outside worktree
# ═══════════════════════════════════════════════════
# export OMC_ALLOW_EXTERNAL_WORKDIR=1

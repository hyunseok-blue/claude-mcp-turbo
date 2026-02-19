# Troubleshooting Guide

## Common Issues

### 1. "Codex rate limit error" on every call (False Positive)

**Symptom**: Codex calls fail with rate limit error even though you have Pro Max quota.

**Cause**: `isRateLimitError()` regex `rate.?limit` matches `rate_limit` variable names
in Codex's response text (JSONL output contains source code analysis).

**Fix**: Run `bin/patch-omc.sh` to apply the regex fix (`rate[- ]limit`).

### 2. "Sibling tool call errored" on Gemini

**Symptom**: Gemini calls fail when Codex is called in parallel.

**Cause**: When Codex fails with the false positive above, the parallel Gemini call
also fails as a "sibling tool call errored" cascading failure.

**Fix**: Fix the root cause (Codex false positive) with `bin/patch-omc.sh`.

### 3. MCP tools not found / not available

**Symptom**: `ask_codex` or `ask_gemini` tools are not available in Claude Code.

**Checks**:
1. Verify CLI installation: `codex --version` / `gemini --version`
2. Verify OMC plugin: `ls ~/.claude/plugins/cache/omc/`
3. Run `bin/doctor.sh` for full diagnostic

### 4. Patches lost after OMC update

**Symptom**: After OMC version update, Codex errors return.

**Cause**: OMC plugin cache is replaced on version update.

**Fix**: Re-run `bin/patch-omc.sh` — it auto-detects the latest version.

### 5. Environment variables not loaded

**Symptom**: `echo $OMC_CODEX_DEFAULT_MODEL` is empty.

**Fix**:
```bash
# setup.sh가 자동으로 셸 RC 파일에 등록합니다 (zsh/bash 자동 감지)
# 수동 등록이 필요하면:
source /path/to/claude-mcp-turbo/config/env.sh 2>/dev/null

# 현재 셸에 반영:
source ~/.zshrc  # 또는 ~/.bashrc
```

### 6. .omc-config.json has useMcp: false

**Symptom**: MCP tools are never auto-routed by OMC.

**Fix**:
```bash
# Re-run setup:
bin/setup.sh

# Or manually edit:
# ~/.claude/.omc-config.json → "useMcp": true
```

## Diagnostic Commands

```bash
# clone 디렉토리에서 실행 (또는 절대 경로 사용)
cd /path/to/claude-mcp-turbo

# Full health check
bin/doctor.sh

# Usage dashboard
bin/status.sh

# Re-apply everything
bin/setup.sh

# Just re-apply patches
bin/patch-omc.sh
```

## Verifying Fixes

After applying patches, test in a new Claude Code session:

```
# In Claude Code, run:
ask_codex(agent_role="architect", prompt="Hello, respond with OK")

# Expected: successful response, no rate limit error
# If still failing: check bin/doctor.sh output
```

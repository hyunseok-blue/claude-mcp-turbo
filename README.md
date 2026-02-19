# Claude MCP Turbo

Codex Pro Max + Gemini MCP 최적화 설정 & OMC 버그 패치.

## 문제

OMC v4.2.15에서 Codex/Gemini MCP 호출 시:
- **Codex 에러**: `isRateLimitError()`의 regex `rate.?limit`가 응답 본문의 `rate_limit` 변수명을 매칭 (false positive)
- **Gemini 에러**: Codex 실패의 연쇄 에러 (sibling tool call errored)
- **MCP 미활용**: `useMcp: false` 설정으로 자동 라우팅 비활성

## 해결

```bash
# 원커맨드 설치
~/claude-mcp-turbo/bin/setup.sh
```

이 스크립트가 하는 일:
1. 환경변수 설정 (Codex Pro Max 최적화)
2. `.omc-config.json` 업데이트 (`useMcp: true`, 역할별 프로바이더 라우팅)
3. `CLAUDE.md`에 MCP-first 정책 추가
4. OMC 버그 패치 적용
5. 전체 진단 실행

## 구조

```
claude-mcp-turbo/
├── bin/
│   ├── setup.sh          # 원커맨드 설치
│   ├── doctor.sh         # 건강 진단 (8개 체크)
│   ├── status.sh         # 사용 현황 대시보드
│   ├── update.sh         # 설정 업데이트
│   └── patch-omc.sh      # OMC 버그 패치 (업데이트 후 재실행)
├── config/
│   ├── env.sh            # 환경변수 (Pro Max 최적화)
│   ├── omc-config.patch.json   # .omc-config.json 패치
│   ├── model-routing.json      # 역할→프로바이더 라우팅
│   └── claude-md-patch.md      # CLAUDE.md MCP-first 정책
├── patches/
│   ├── codex-core.patch  # isRateLimitError 수정
│   └── gemini-core.patch # isGeminiRetryableError 수정
└── docs/
    └── TROUBLESHOOTING.md
```

## 일상 사용

```bash
# 진단
~/claude-mcp-turbo/bin/doctor.sh

# 상태 확인
~/claude-mcp-turbo/bin/status.sh

# OMC 업데이트 후 패치 재적용
~/claude-mcp-turbo/bin/patch-omc.sh
```

## 버그 상세

### `rate.?limit` → `rate[- ]limit`

원본 regex `rate.?limit`에서 `.?`는 **임의의 문자 0~1개**를 매칭.
`rate_limit` (underscore)도 매칭되어 Codex 응답 본문에 포함된
Python 변수명이 rate limit 에러로 오탐.

수정: `rate[- ]limit` — 하이픈과 공백만 허용, underscore 제외.

### Event Type Filtering

Codex JSONL 출력에서 `item.completed`, `message`, `output_text` 등
정상 응답 이벤트는 스킵하고, `error`와 `turn.failed` 이벤트만 검사.

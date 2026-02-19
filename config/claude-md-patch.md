<mcp_first_policy>
## MCP-First 실행 정책 (Codex Pro Max)

분석/리뷰/설계 작업은 Claude 에이전트 대신 MCP를 우선 사용:

### 자동 MCP 라우팅 (Claude 에이전트 대신 MCP 호출)
| 역할 | MCP 프로바이더 | 용도 |
|------|--------------|------|
| architect | ask_codex | 아키텍처 설계/리뷰 |
| planner | ask_codex | 구현 계획 검증 |
| critic | ask_codex | 플랜/설계 비평 |
| analyst | ask_codex | 요구사항 분석 |
| code-reviewer | ask_codex | 코드 리뷰 |
| security-reviewer | ask_codex | 보안 리뷰 |
| designer | ask_gemini | UI/UX 디자인 리뷰 |
| writer | ask_gemini | 문서 작성 |
| vision | ask_gemini | 이미지/스크린샷 분석 |

### 실행 규칙
1. 위 역할의 분석/리뷰 작업 → MCP 우선 호출 (background: true로 병렬)
2. MCP 실패 시 → Claude 에이전트로 폴백
3. 구현/디버깅/검증 등 도구 접근 필요 → Claude 에이전트 직접 사용
4. 리뷰 작업 시 Codex + Claude 크로스 검증 적극 활용
5. 대규모 파일 분석 → Gemini (1M 토큰 컨텍스트) 우선
</mcp_first_policy>

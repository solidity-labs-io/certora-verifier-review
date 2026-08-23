# Page 1 — Executive Summary

## What this is

In August 2026, six frontier LLM agents were each given an identical, unaided security-audit task against the **Kleidi** codebase — a Safe-based multisig wallet with hot/cold signer separation, a custom timelock, and whitelisted calldata checks — at the **exact commit submitted to the Code4rena contest of October 15–25, 2024** (`0d72b6cb5725c1380212dc76257da96fcfacf22f`). The models received no hints about vulnerable areas, no access to git history or branches, no internet research about the repo, and could not see the C4 report. Each produced a structured `FINDINGS.md` (Medium/High severity only, mandatory PoC).

## Headline results

| Rank | Model | Findings | High | Medium | Distinct valid issues | C4 ground-truth coverage |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | GLM 5.3 | 5 | 1 | 4 | 5 | Partial (M-01 escalation; M-02 subsystem) |
| 2 | Claude | 5 | 0 | 5 | 5 | Partial (M-02 subsystem) |
| 3 | DeepSeek v4 | 3 | 1 | 2 | 3 | None direct |
| 4 | OpenAI | 3 | 0 | 3 | 3 | Partial (M-03 variable) |
| 5 | ox-alpha | 2 | 0 | 2 | 2 | Partial (M-03 variable) |
| 6 | GLM 5.2 | 0 | 0 | 0 | 0 | None |

After deduplication, the six models surfaced **13 distinct issues**: 11 assessed as plausibly valid by cross-examination, plus 2 lower-confidence ones. Several are **not present in the C4 report** — i.e., candidate misses by the original 27-warden competition.

## Key takeaways

1. **The calldata-check subsystem attracted the most attention.** Three of six models (Claude, GLM 5.3) found real off-by-one behavior in the range-overlap validation of `addCalldataCheck` — the same subsystem where C4's M-02 lived, though expressed as the inverse symptom (valid adjacent ranges *rejected*, forcing unchecked gap bytes that a hot signer can tamper with).
2. **Two models escalated the proposal-lifecycle DoS.** GLM 5.3 showed the guardian `pause()` brake can be made to permanently exceed block gas limits (unbounded live-proposal set + unbounded per-proposal delay), a materially stronger claim than C4's M-01 gas-griefing finding.
3. **The recovery path is under-defended in ways C4 missed.** Four distinct novel issues: transient-storage duplicate-owner leak across batched spell creations (ox-alpha, Claude); SENTINEL/invalid owners accepted at factory level bricking recovery forever (Claude, GLM 5.3, OpenAI); zero `recoveryThreshold` accepted enabling signature-free owner rotation (Claude); and recovery delay elapsing before module enablement (GLM 5.3, OpenAI).
4. **One model failed completely.** GLM 5.2 returned zero findings despite claiming full coverage.
5. **No model exactly reproduced any of the three C4 Mediums as written**, but near-neighbors were found for all three — see Page 5.

## Economic observation

DeepSeek v4 was the only model to attack the whitelist configuration itself (unpinned Morpho markets, wildcard Compound `mint`) rather than only contract logic — the highest-severity single finding of the run (compromised hot signer drains all collateral through a permissionlessly created market).

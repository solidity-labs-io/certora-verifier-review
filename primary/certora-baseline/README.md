# Certora Baseline Report

**File:** `audit-report-final.json` (43.9 KB)

Independent full-audit baseline produced by Certora's auditing pipeline against the **same snapshot** given to the six LLM agents:

| Config key | Value |
| --- | --- |
| Target | https://github.com/solidity-labs-io/kleidi |
| Branch / commit | `0d72b6cb5725c1380212dc76257da96fcfacf22f` |
| Audit type | full |
| Date | 2026-08-22 23:43 UTC |
| Max iterations | 10 |
| Context | all 17 `src/` files + 13 `docs/` files |

## Result distribution

| Severity | Count |
| --- | --- |
| High | 0 |
| Medium | 3 |
| Low | 10 |
| Info | 24 |

## Mediums

- **M-01** Unbounded loop in `pause()` lets a compromised Safe permanently disable the guardian via gas griefing
- **M-02** Index-based whitelist removals via swap-and-pop lead to order dependency and silently desynchronize off-chain views
- **M-03** Recovery spells are mutually non-exclusive and cannot be quickly disabled by recovered owners

## Why it matters for this evaluation

The baseline provides a third reference frame alongside the six model outputs and the historical Code4rena findings: every model claim that also appears in this independently produced report is corroborated evidence rather than an isolated assertion. Cross-reference table in [`../../report/page-5-scoring-and-conclusions.md`](../../report/page-5-scoring-and-conclusions.md).

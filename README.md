# Independent Pre-Audit Model Evaluation — Kleidi (solidity-labs-io)

Seven frontier LLM agents independently audited the Kleidi codebase at its exact pre-Code4rena state (`0d72b6cb5725c1380212dc76257da96fcfacf22f`, 2024-10-17), blind to the C4 findings. This repo contains the final reviewer comparison, each model's raw findings, and the primary evidence (codebase snapshot, provenance, Certora baseline, C4 report).

## **Read the final report: [REPORT.md](REPORT.md)**

Three pages: master comparison table (all 9 reviewers) · per-reviewer profiles · accuracy analysis with the 20-issue canonical set, coverage matrix, and verdict.

## **Canonical findings index: [findings/CANONICAL.md](findings/CANONICAL.md)**

Master cross-reference: every unique issue gets a `KLD-NNN` identifier and normalized severity, with per-auditor mapping and coverage matrix.

## Reviewer outputs (`findings/` and `primary/`)

| Reviewer | Type | Findings | High | Medium |
| --- | --- | --- | --- | --- |
| [Code4rena](primary/c4-report/) | Human contest | 14 | 0 | 3 |
| [Certora](primary/certora-baseline/) | Automated pipeline | 37 | 0 | 3 |
| [v12](findings/v12.md) | LLM | 8 | 0 | 8 |
| [GLM 5.3 Flash](findings/glm-5.3-flash.md) | LLM | 2 | 0 | 2 |
| [Claude](findings/claude.md) | LLM | 5 | 0 | 5 |
| [DeepSeek v4](findings/deepseek-v4.md) | LLM | 2 | 0 | 2 |
| [GLM 5.2](findings/glm-5.2.md) | LLM | 2 | 0 | 2 |
| [GLM 5.3](findings/glm-5.3.md) | LLM | 5 | 1 | 4 |
| [Codex](findings/codex.md) | LLM | 4 | 0 | 4 |

## Primary documents (`primary/`)

- [`codebase/`](primary/codebase/) — full Kleidi working tree at the audited commit
- [`PROVENANCE.md`](primary/PROVENANCE.md) — commit hashes, snapshot verification against the C4 contest repo, audit window
- [`c4-report/`](primary/c4-report/) — Code4rena October 2024 findings (0H/3M + low/QA)
- [`certora-baseline/`](primary/certora-baseline/README.md) — independent Certora audit of the same commit (0H/3M/10L/24I)
- [`poc/claude/`](primary/poc/claude/) — Claude's 8-test Foundry PoC suite
- [`recon/`](primary/recon/) — sponsor recon PDF available to models during runs
- [`AUDIT_PROMPT.md`](primary/AUDIT_PROMPT.md) — the identical task prompt given to all models

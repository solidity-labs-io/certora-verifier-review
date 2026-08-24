# Independent Pre-Audit Model Evaluation — Kleidi (solidity-labs-io)

Six frontier LLM agents independently audited the Kleidi codebase at its exact pre-Code4rena state (`0d72b6cb5725c1380212dc76257da96fcfacf22f`, 2024-10-17), blind to the C4 findings. This repo contains the final reviewer comparison, each model's raw findings, and the primary evidence (codebase snapshot, provenance, Certora baseline, C4 report).

## **Read the final report: [REPORT.md](REPORT.md)**

Three pages: master comparison table (all 8 reviewers) · per-reviewer profiles · accuracy analysis with the 17-issue canonical set, coverage matrix, and verdict.

## Raw model outputs (`findings/`)

| Model | Findings | High | Medium |
| --- | --- | --- | --- |
| [ox-alpha](findings/0x-alpha.md) | 2 | 0 | 2 |
| [Claude](findings/claude.md) | 5 | 0 | 5 |
| [DeepSeek v4](findings/deepseek-v4.md) | 3 | 0 | 3 |
| [GLM 5.2](findings/glm-5.2.md) | **0** | 0 | 0 |
| [GLM 5.3](findings/glm-5.3.md) | 5 | 1 | 4 |
| [Codex](findings/codex.md) | 3 | 0 | 3 |

(DeepSeek's Morpho finding was reported High; review re-rated it Medium — see REPORT.md.)

## Primary documents (`primary/`)

- [`codebase/`](primary/codebase/) — full Kleidi working tree at the audited commit
- [`PROVENANCE.md`](primary/PROVENANCE.md) — commit hashes, snapshot verification against the C4 contest repo, audit window
- [`c4-report/`](primary/c4-report/) — Code4rena October 2024 findings (0H/3M + low/QA)
- [`certora-baseline/`](primary/certora-baseline/README.md) — independent Certora audit of the same commit (0H/3M/10L/24I)
- [`poc/claude/`](primary/poc/claude/) — Claude's executed PoC test suite (8 passing tests)
- [`recon/`](primary/recon/) — sponsor recon PDF available to models during runs
- [`AUDIT_PROMPT.md`](primary/AUDIT_PROMPT.md) — the identical task prompt given to all six models

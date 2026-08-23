# Independent Pre-Audit Model Evaluation — Kleidi (solidity-labs-io)

Six frontier LLM agents independently audited the Kleidi codebase at its exact pre-Code4rena state (`0d72b6cb5725c1380212dc76257da96fcfacf22f`, 2024-10-17), blind to the C4 findings. This repo contains the 5-page comparative report, each model's raw findings, and the primary evidence (codebase snapshot, provenance).

## Report

| Page | Contents |
| --- | --- |
| [Page 1](report/page-1-executive-summary.md) | Executive summary |
| [Page 2](report/page-2-methodology-and-provenance.md) | Methodology, provenance, ground truth |
| [Page 3](report/page-3-consolidated-findings.md) | Consolidated findings matrix |
| [Page 4](report/page-4-model-by-model-analysis.md) | Model-by-model analysis |
| [Page 5](report/page-5-scoring-and-conclusions.md) | Scoring vs. C4 ground truth & conclusions |

## Raw model outputs

| Model | Findings | High | Medium |
| --- | --- | --- | --- |
| [ox-alpha](findings/0x-alpha.md) | 2 | 0 | 2 |
| [Claude](findings/claude.md) | 5 | 0 | 5 |
| [DeepSeek v4](findings/deepseek-v4.md) | 3 | 1 | 2 |
| [GLM 5.2](findings/glm-5.2.md) | **0** | 0 | 0 |
| [GLM 5.3](findings/glm-5.3.md) | 5 | 1 | 4 |
| [OpenAI](findings/openai.md) | 3 | 0 | 3 |

## Primary documents

- [`primary/codebase/`](primary/codebase/) — full Kleidi working tree at the audited commit
- [`primary/PROVENANCE.md`](primary/PROVENANCE.md) — commit hashes, snapshot verification against the C4 contest repo, audit window

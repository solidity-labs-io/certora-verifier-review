# Provenance

## Repository

- Upstream: `git@github.com:solidity-labs-io/kleidi.git` (public mirror: github.com/solidity-labs-io/kleidi)
- System: Kleidi — Safe-based multisig wallet with timelock, hot-signer whitelist, recovery spells

## Audited state

| Item | Hash / value |
| --- | --- |
| Commit given to all six models | `0d72b6cb5725c1380212dc76257da96fcfacf22f` |
| Subject | Merge pull request #48 from solidity-labs-io/feat/deploy-testnets |
| Date | 2024-10-17 |
| `src/` tree hash | `bf2d076ffee8c7c386e15e18aa2c5f3039a56e30` |

## Equivalence to the Code4rena contest snapshot

The C4 contest repo (`https://github.com/code-423n4/2024-10-kleidi`) init commit:

| Item | Hash / value |
| --- | --- |
| Contest init commit ("Contest repo init", committer c4-audit) | `c474b9480850d08514c100b415efcbc962608c62` |
| Init date | 2024-10-09 |
| `src/` tree hash | `bf2d076ffee8c7c386e15e18aa2c5f3039a56e30` — **identical to the audited commit** |

Verification method: fetched the contest init commit into the local object store and compared subtree hashes for `src/`. The working tree differences between the audited commit and the snapshot are limited to non-src files (C4 scope/out-of-scope manifests, docs, README); the Solidity under audit is byte-for-byte identical.

The competition ran **October 15–25, 2024**; the first post-audit commit upstream is:

| Item | Hash / value |
| --- | --- |
| First post-audit commit | `d2df6baf51d36faa99175ba0f293954b2ed62cb4` |
| Subject | fix: c4 audit finding, allow end and start index to overlap for single byte |
| Date | 2024-10-28 |

## Evaluation conditions

- Six isolated working copies, one per model, all at the commit above.
- `.git` removed from each copy before the run (no history, no branches, no remote refs).
- Identical task prompt (`AUDIT_PROMPT.md`, copied into this repo's root history below); Medium/High-only, mandatory PoC, fixed FINDINGS.md schema.
- Models could not access the C4 report; it is not present in the tree at this commit.

## Ground truth reference

- C4 report: https://code4rena.com/reports/2024-10-kleidi (published 2024-11-20)
- Outcome: 3 Medium (M-01 gas griefing via proposals; M-02 calldata index handling; M-03 updateExpirationPeriod execution), 11 low/QA, 0 High/Critical

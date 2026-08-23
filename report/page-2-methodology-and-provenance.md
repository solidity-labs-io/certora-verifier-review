# Page 2 — Methodology, Provenance & Ground Truth

## Target

**Kleidi** (solidity-labs-io/kleidi): a Safe{Wallet}-centric account-abstraction system. Cold signers (Safe owners) govern through a custom `Timelock`; hot signers get day-to-day execution power bounded by whitelisted calldata byte-range checks (`addCalldataCheck` / `executeWhitelisted`); a `Guard` enforces time restrictions; `RecoverySpell` provides social recovery; `InstanceDeployer` deploys deterministic cross-chain instances; DeFi integrations (Morpho, Compound/WETH) ship as reference whitelist configurations. ~1,400 nSLOC; `Timelock.sol` alone is 1,344 lines.

## Provenance (see primary/PROVENANCE.md)

| Item | Value |
| --- | --- |
| Audited commit (all six runs) | `0d72b6cb5725c1380212dc76257da96fcfacf22f` — Merge PR #48, 2024-10-17 |
| C4 contest snapshot | `c474b9480850d08514c100b415efcbc962608c62` (code-423n4/2024-10-kleidi, "Contest repo init") |
| Snapshot equivalence | `src/` tree hash `bf2d076ffee8c7c386e15e18aa2c5f3039a56e30` **byte-identical** between audited commit and C4 snapshot (verified by git tree-hash comparison) |
| First post-audit commit | `d2df6baf51d36faa99175ba0f293954b2ed62cb4` — "fix: c4 audit finding…" (2024-10-28) |
| C4 competition | Oct 15–25 2024, 27 wardens, judged by Alex the Entreprenerd; report 2024-11-20 |

## Protocol given to every model (identical)

- Audit only `src/`; read `test/`, `certora/`, `docs/`, `lib/` for context.
- Read-only: no file modification, no git operations (`.git` physically removed from each working copy), no internet research about the repo.
- No focus hints — models chose their own targets.
- Output: `FINDINGS.md` with Medium/High findings only, each with file:line, description, attack scenario, and a mandatory concrete PoC; coverage section required.

## Anti-cheating measures

1. Checked out the pre-audit commit, at which `audit/Code4rena.md` and the C4 recon PDF do not exist in the tree.
2. Deleted `.git` in all six working copies — removing commit history *and* local remote refs whose branch names (e.g. `docs/add-expiration-period-known-issue`) would have leaked post-audit knowledge.
3. Identical prompt, identical snapshot, no per-model tuning.
4. Disclosure: the sponsor **recon PDF** (`Kleidi-Recon-Report.pdf`) was present in all six working copies. This matches contest conditions — C4 wardens received the same recon — but readers should know models had more than bare source. No model's output references the C4 findings report, which was verifiably absent from every copy.

## Ground truth: C4 findings being measured against

| C4 ID | Finding | Final severity |
| --- | --- | --- |
| M-01 | Gas griefing via mass proposal scheduling; defense (`pause`/`cancel`) costs gas | Medium |
| M-02 | Calldata-check index handling wrong (`length = end - start` missing `+1` in `sliceBytes` and `_addCalldataCheck`) → full-32-byte params force reverts | Medium |
| M-03 | `_afterCall` re-checks readiness against a *newly lowered* `expirationPeriod` → `updateExpirationPeriod` can become unexecutable | Medium |

Plus 11 low/QA reports. No High/Critical findings were produced by the C4 competition.

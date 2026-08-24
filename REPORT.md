# Kleidi Pre-C4 LLM Audit Evaluation — Full Report

Six frontier LLM agents independently audited the Kleidi codebase at its exact pre-Code4rena state (`0d72b6cb5725c1380212dc76257da96fcfacf22f`, 2024-10-17), blind to the C4 findings. This report compares their outputs against each other, against the C4 competition results, and against an independent Certora baseline produced on the same commit.

**Contents:** [1. Executive Summary](#1--executive-summary) · [2. Methodology & Provenance](#2--methodology--provenance) · [3. Consolidated Findings](#3--consolidated-findings) · [4. Model-by-Model Analysis](#4--model-by-model-analysis) · [5. Scoring & Conclusions](#5--scoring--conclusions)

---

## 1 · Executive Summary

### What this is

In August 2026, six frontier LLM agents were each given an identical, unaided security-audit task against **Kleidi** — a Safe-based multisig wallet with hot/cold signer separation, a custom timelock, and whitelisted calldata checks — at the **exact commit submitted to the Code4rena contest of October 15–25, 2024**. The models received no hints about vulnerable areas, no access to git history or branches, no internet research about the repo, and could not see the C4 report. Each produced a structured `FINDINGS.md` (Medium/High severity only, mandatory PoC).

### Headline results

| Rank | Model | Findings | High | Medium | Distinct valid issues | C4 ground-truth coverage |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | GLM 5.3 | 5 | 1 | 4 | 5 | Partial (M-01 escalation; M-02 subsystem) |
| 2 | Claude | 5 | 0 | 5 | 5 | Partial (M-02 subsystem) |
| 3 | DeepSeek v4 | 3 | 0 | 3 | 3 | None direct |
| 4 | OpenAI | 3 | 0 | 3 | 3 | Partial (M-03 variable) |
| 5 | ox-alpha | 2 | 0 | 2 | 2 | Partial (M-03 variable) |
| 6 | GLM 5.2 | 0 | 0 | 0 | 0 | None |

After deduplication, the six models surfaced **13 distinct issues**. Cross-examination against the Certora baseline corroborates 7 of them; none are contradicted.

### Key takeaways

1. **The calldata-check subsystem attracted the most attention.** Two of six models (Claude, GLM 5.3) found real off-by-one behavior in the range-overlap validation of `addCalldataCheck` — the same subsystem where C4's M-02 lived, though expressed as the inverse symptom (valid adjacent ranges *rejected*, forcing unchecked gap bytes that a hot signer can tamper with).
2. **One model escalated the proposal-lifecycle DoS.** GLM 5.3 showed the guardian `pause()` brake can be made to permanently exceed block gas limits (unbounded live-proposal set + unbounded per-proposal delay) — the run's only High finding, and a materially stronger claim than C4's M-01 gas-griefing finding.
3. **The recovery path is under-defended in ways C4 missed.** Four distinct novel issues: transient-storage duplicate-owner leak across batched spell creations (ox-alpha, Claude); SENTINEL/invalid owners accepted at factory level bricking recovery forever (Claude, GLM 5.3, OpenAI); zero `recoveryThreshold` accepted enabling signature-free owner rotation (Claude); and recovery delay elapsing before module enablement (GLM 5.3, OpenAI).
4. **One model failed completely.** GLM 5.2 returned zero findings despite claiming full coverage.
5. **No model exactly reproduced any of the three C4 Mediums as written**, but near-neighbors were found for all three — see Section 5.

---

## 2 · Methodology & Provenance

### Target

**Kleidi** (solidity-labs-io/kleidi): a Safe{Wallet}-centric account-abstraction system. Cold signers (Safe owners) govern through a custom `Timelock`; hot signers get day-to-day execution power bounded by whitelisted calldata byte-range checks (`addCalldataCheck` / `executeWhitelisted`); a `Guard` enforces time restrictions; `RecoverySpell` provides social recovery; `InstanceDeployer` deploys deterministic cross-chain instances; DeFi integrations (Morpho, Compound/WETH) ship as reference whitelist configurations. ~1,400 nSLOC; `Timelock.sol` alone is 1,344 lines.

### Provenance (see [primary/PROVENANCE.md](../primary/PROVENANCE.md))

| Item | Value |
| --- | --- |
| Audited commit (all six runs) | `0d72b6cb5725c1380212dc76257da96fcfacf22f` — Merge PR #48, 2024-10-17 |
| C4 contest snapshot | `c474b9480850d08514c100b415efcbc962608c62` (code-423n4/2024-10-kleidi, "Contest repo init") |
| Snapshot equivalence | `src/` tree hash `bf2d076ffee8c7c386e15e18aa2c5f3039a56e30` **byte-identical** between audited commit and C4 snapshot (verified by git tree-hash comparison) |
| First post-audit commit | `d2df6baf51d36faa99175ba0f293954b2ed62cb4` — "fix: c4 audit finding…" (2024-10-28) |
| C4 competition | Oct 15–25 2024, 27 wardens, judged by Alex the Entreprenerd; report 2024-11-20 |

### Protocol given to every model (identical)

- Audit only `src/`; read `test/`, `certora/`, `docs/`, `lib/` for context.
- Read-only: no file modification, no git operations (`.git` physically removed from each working copy), no internet research about the repo.
- No focus hints — models chose their own targets.
- Output: `FINDINGS.md` with Medium/High findings only, each with file:line, description, attack scenario, and a mandatory concrete PoC; coverage section required.

### Anti-cheating measures

1. Checked out the pre-audit commit, at which `audit/Code4rena.md` and the C4 findings report do not exist in the tree.
2. Deleted `.git` in all six working copies — removing commit history *and* local remote refs whose branch names (e.g. `docs/add-expiration-period-known-issue`) would have leaked post-audit knowledge.
3. Identical prompt, identical snapshot, no per-model tuning.
4. Disclosure: the sponsor **recon PDF** (`Kleidi-Recon-Report.pdf`) was present in all six working copies. This matches contest conditions — C4 wardens received the same recon — but readers should know models had more than bare source. No model's output references the C4 findings report, which was verifiably absent from every copy.

### Ground truth: two reference frames

**Frame 1 — Code4rena competition (Oct 15–25 2024, 27 wardens):**

| C4 ID | Finding | Final severity |
| --- | --- | --- |
| M-01 | Gas griefing via mass proposal scheduling; defense (`pause`/`cancel`) costs gas | Medium |
| M-02 | Calldata-check index handling wrong (`length = end - start` missing `+1` in `sliceBytes` and `_addCalldataCheck`) → full-32-byte params force reverts | Medium |
| M-03 | `_afterCall` re-checks readiness against a *newly lowered* `expirationPeriod` → `updateExpirationPeriod` can become unexecutable | Medium |

Plus 11 low/QA reports. No High/Critical findings were produced by the C4 competition.

**Frame 2 — Certora baseline (2026-08-22, same commit, independent pipeline):** 0 High / 3 Medium / 10 Low / 24 Info — raw JSON and summary under [`primary/certora-baseline/`](../primary/certora-baseline/README.md). Used to corroborate (or contradict) model findings; cross-reference in Section 5.

---

## 3 · Consolidated Findings

13 distinct issues after deduplication. Severity shown is the **review-adjusted** rating (where a reporter's rating differed from the assessed one, both are noted). Attribution: **bold** = reported by that model.

### F1 · Medium — Unbounded `expirationPeriod` overflows readiness checks, permanently bricking execution
`Timelock.sol L289, L972–977, L399–404`
**ox-alpha** · **OpenAI**
`updateExpirationPeriod` enforces only a lower bound; `isOperationReady`/`isOperationExpired` add it to timestamps with checked arithmetic. A period near `2^256` makes every `execute`/`cleanup` revert — including the repair proposal. ox-alpha's PoC was an executed Foundry test demonstrating the repair itself is unexecutable.

### F2 · Medium — Transient `tstore` duplicate-owner flags leak across calls
`RecoverySpellFactory.sol L58–71`
**ox-alpha** · **Claude**
EIP-1153 transient storage is never cleared, so batched `createRecoverySpell` calls sharing any owner revert with "Duplicate owner"; downstream, dead counterfactual spell addresses can be enabled as Safe modules.

### F3 · Medium — Overlap check rejects valid adjacent ranges, forcing exploitable unchecked gap bytes
`Timelock.sol L1119–1123`
**Claude** · **GLM 5.3**
Strict inequalities on the range-overlap check reject disjoint adjacent parameter checks. The natural `[37, 68)` workaround leaves one byte unchecked; GLM 5.3 built the full exploit (hot signer tampering that byte to multiply the whitelisted amount by ~2^248). Same subsystem as C4 M-02; this is the strict-inequality aspect the team also fixed post-audit (`d2df6ba`).

### F4 · Medium — SENTINEL `address(1)` (and Safe itself) accepted as recovery owner → recovery permanently bricked
`RecoverySpellFactory.sol L135–137`
**Claude** · **GLM 5.3** · **OpenAI**
Factory validates only `address(0)`; Safe's OwnerManager rejects SENTINEL (GS203/GS013), so `executeRecovery` reverts forever. Three-model consensus — the strongest signal of the run.

### F5 · Medium — Zero `recoveryThreshold` accepted → signature-free owner rotation
`RecoverySpellFactory.sol L118–138`
**Claude**
Asymmetric validation: `threshold != 0` is checked, `recoveryThreshold` is not. With zero, `executeRecovery` passes the signature gate with empty arrays and rotates all owners. Unique to Claude; arguably High.

### F6 · Medium (low confidence) — `initialize()` front-runnable on directly-deployed timelocks
`Timelock.sol L316–329`
**Claude**
Only a one-shot flag guards initialization; the documented flow initializes atomically, so exposure is limited to off-protocol deployments. Correctly self-rated low confidence.

### F7 · Medium — Morpho whitelist does not pin `MarketParams` for `supplyCollateral`/`borrow`
`Timelock.sol L475–504, L715–755`
**DeepSeek v4** *(reported High; re-rated Medium)*
A compromised hot signer can post the timelock's collateral into a permissionlessly created market and liquidate it. Re-rated: the attack requires an already-compromised hot signer (at which point simpler drains exist), and the Certora baseline independently rates the underlying configuration flaw **Low**. The observation itself is valid and unique in this run — DeepSeek was the only model to audit the whitelist *configuration* rather than only contract code.

### F8 · Medium — Wildcard Compound `mint [4,4)` + unchecked `msg.value` freezes entire native balance
`Timelock.sol L488–493`
**DeepSeek v4**
No whitelisted exit exists (`redeem` not whitelisted), so a hot signer can lock all ETH in cETH pending a full governance proposal.

### F9 · Medium — Single-owner instances silently deploy threshold-1 regardless of requested `threshold`
`InstanceDeployer.sol L315–328`
**DeepSeek v4**
The final `addOwnerWithThreshold` is skipped when `owners.length == 1`; requested threshold 2 silently becomes 1.

### F10 · High — Guardian `pause()` can be made permanently OOG → emergency brake neutralized
`Timelock.sol L521–539, L687–700`
**GLM 5.3** — the run's only High
Unbounded `_liveProposals` set + unbounded per-proposal delay (junk never expires, `cleanup` can't shrink) → `pause()` always exceeds block gas, then the malicious proposal executes permissionlessly. A strict escalation of C4 M-01; independently corroborated by Certora baseline M-01 (rated Medium there).

### F11 · Medium — Recovery delay clock starts at permissionless deployment, not module enablement
`RecoverySpell.sol L124`
**GLM 5.3** · **OpenAI**
A counterfactually pre-deployed spell can be fully aged before `createSystemInstance` enables it, eliminating the cold-signer veto window. Two independent framings (cross-chain front-run; compromised recovery quorum).

### F12 · Medium — `executeRecovery` reverts forever when spell `owners[0]` equals the surviving oldest Safe owner
`RecoverySpell.sol L259–273`
**GLM 5.3**
The "keep the primary signer" configuration collides with Safe's GS013 (new owner must not already be an owner). Unique to GLM 5.3.

*GLM 5.2: no findings (coverage list only).*

---

## 4 · Model-by-Model Analysis

### GLM 5.3 — 5 findings (1 High, 4 Medium) — strongest overall

- **F10 (High, the run's only High):** only model to show the guardian brake itself can be *neutralized*: unbounded `_liveProposals` + unbounded per-proposal delay → `pause()` always OOGs, then the malicious proposal executes permissionlessly. A strict escalation of C4 M-01.
- **F3:** the overlap off-by-one, plus a concrete exploit through the forced gap byte (MSB of `amount` tampered → ~2^248 transfer).
- **F4, F11, F12:** recovery-path trio; F12 (survivor-collision `swapOwner(SENTINEL, alice, alice)`) is unique to this model and not in the C4 report.
- Weakness: F11/F12 confidence self-rated Medium; PoCs are outlines rather than executed tests.

### Claude — 5 findings (0 High, 5 Medium) — broadest recovery-path coverage

*Post-run update:* Claude's polished artifact report confirms all five PoCs were validated with **8 runnable Foundry tests (`test/unit/AuditFindings.t.sol`, 407 lines) — all passing** against unmodified source. This upgrades its PoC quality to "executed" and adds an explicit negative-results section (areas cleared). Two caveats: (a) writing the test file technically deviated from the read-only instruction; (b) its negative results include one notable **false negative** — it explicitly cleared `BytesHelper.sliceBytes` as "correctly validating bounds," which is precisely where C4's M-02 off-by-one lived.

- **F2** transient-storage leak found independently of ox-alpha (consensus signal).
- **F3** overlap off-by-one — but its PoC assumes end-exclusive range semantics; audited code's `sliceBytes` treats ranges inclusively (the very confusion behind C4 M-02). The observed rejection of adjacent ranges is nonetheless real behavior, and matches the issue the team actually fixed post-audit (`d2df6ba` "allow end and start index to overlap for single byte").
- **F4, F5:** SENTINEL owners and the asymmetric `threshold` vs `recoveryThreshold` validation gap — F5 is unique to Claude and plausibly High in impact.
- **F6 (Low confidence):** front-runnable `initialize` on direct factory deployments — real pattern, but the system's documented flow always initializes atomically; correctly self-rated Low confidence.

### DeepSeek v4 — 3 findings (0 High, 3 Medium) — most attacker-economics-driven

- **F7 (Medium, reported High — re-rated):** only model to audit the *whitelist configuration* rather than just contract code: unpinned Morpho `MarketParams` on `supplyCollateral`/`borrow` → compromised hot signer posts collateral into a self-created market and liquidates it. Full end-to-end chain including `createMarket` permissionlessness. Re-rated Medium: the precondition is an already-compromised hot key (simpler thefts available at that point), and the Certora baseline rates the underlying config flaw Low.
- **F8:** wildcard Compound `mint` + unchecked `value` → whole native balance locked in cETH with no whitelisted exit; cites the project's own EDGECASES.md requirement.
- **F9:** silent threshold collapse to 1-of-1 for single-owner instances.
- Weakness: no findings in the Timelock lifecycle/recovery path; coverage claims full sweep.

### OpenAI — 3 findings (0 High, 3 Medium) — precise but narrow

- **F1, F4, F11:** one Timelock overflow variant, and consensus hits on both recovery issues.
- All three PoCs are concrete and correct in shape; zero false positives in the set.
- Weakness: no novel single-discoverer issues; smallest distinct-issue surface among non-empty reporters.

### ox-alpha — 2 findings (0 High, 2 Medium) — small but high-quality

- **F1:** unbounded `expirationPeriod` overflow brick with an executed Foundry PoC, including the nasty detail that the *repair proposal* itself becomes unexecutable.
- **F2:** transient-storage leak, executed PoC, and the downstream consequence chain (dead counterfactual module enabled as Safe module).
- Both findings executed-and-passing tests rather than outlines; zero false positives. Low volume is the main cost.

### GLM 5.2 — 0 findings — failed run

Returned only a coverage list. No findings, no errors, no explanation. Either the model judged the codebase clean (contradicted by 12 sibling findings) or failed to emit structured output. Excluded from quality scoring; a reliability data point in its own right.

---

## 5 · Scoring & Conclusions

### Coverage of the three C4 Mediums

| C4 finding | Reproduced exactly? | Nearest model result |
| --- | --- | --- |
| **M-01** proposal gas griefing vs. defense cost | No — but **exceeded**: GLM 5.3's F10 shows `pause()` can be made *permanently* OOG (unbounded delays prevent expiry/cleanup), converting griefing into full brake neutralization | GLM 5.3 F10 (High) |
| **M-02** off-by-one in index length (`end - start` missing `+1`) → whitelisted calls revert | No model stated the `+1` length bug as such; Claude & GLM 5.3 found the *inverse* symptom in the same subsystem — strict-inequality overlap check rejecting valid adjacent ranges, with GLM 5.3 weaponizing the resulting unchecked gap byte | Claude F3, GLM 5.3 F3 |
| **M-03** readiness re-check uses newly-lowered `expirationPeriod` → update unexecutable | No — but ox-alpha & OpenAI found a different, arguably worse flaw in the same variable: unbounded upper bound → arithmetic overflow bricks all execution including repair proposals | ox-alpha F1, OpenAI F2 |

**Score: 0/3 exact reproductions, but substantive near-miss coverage on 3/3** — each model-cluster landed on the same subsystem C4's wardens flagged, via different defects. LLM auditors reliably find "where," less reliably "what exactly."

### Comparison with the Certora automated audit review

The Certora baseline (2026-08-22, same commit, independent automated pipeline: 0 High / 3 Medium / 10 Low / 24 Info — see `primary/certora-baseline/`) provides a second modern reference frame. Cross-referencing every baseline entry against the model outputs:

| Baseline finding | Sev | Matching model result | Agreement |
| --- | --- | --- | --- |
| M-01 Unbounded `pause()` loop → guardian permanently disabled by gas griefing | M | **GLM 5.3 F10** (rated High) | Exact match; model rated higher |
| M-02 Swap-and-pop removal indices desync queued revocations → wrong check deleted | M | — | **Missed by all six models** |
| M-03 Recovery spells mutually non-exclusive; recovered owners cannot disable other spells | M | — (F11 delay-pre-elapse is an adjacent but distinct defect) | **Missed by all six models** |
| L-01 Morpho documented policies/configs allow asset drain | L | DeepSeek v4 F7 (rated High, re-rated Medium) | Match; both modern reviews converged below model's original rating |
| L-02 Strict inequality blocks contiguous calldata checks | L | Claude F3 + GLM 5.3 F3 (rated Medium) | Exact match |
| L-05 Transient storage pollution breaks batch deploy composability | L | ox-alpha F2 + Claude F2 (rated Medium) | Exact match |
| L-07 Recovery fails when first replacement owner is the retained current owner | L | GLM 5.3 F12 (rated Medium) | Exact match |
| L-09 Inadequate owner-address validation bricks wallets | L | Claude/GLM 5.3/OpenAI F4 (SENTINEL owners, rated Medium) | Partial match |
| I-01 Unbounded delays/expiration periods → arithmetic overflow brick | I | ox-alpha F1 + OpenAI F2 (rated Medium) | Exact match |
| I-05 Single-owner setups silently bypass requested threshold | I | DeepSeek v4 F9 (rated Medium) | Exact match |

#### Takeaways

1. **7 of the models' 13 distinct findings are independently corroborated by the baseline**, including the run's only High (guardian-brake neutralization) and the Morpho market-pinning gap. Zero model findings were flatly contradicted by the baseline.
2. **Systematic severity divergence:** for every corroborated issue the baseline rates one-to-two notches lower than the models (High→M/L, Medium→L/I). The models optimize for impact narratives; the calibrated pipeline discounts exploitability preconditions — exactly the lens that re-rated F7.
3. **The two baseline Mediums that every model missed share a profile:** stateful lifecycle bugs (queued-revocation index drift, multi-spell interaction) that span multiple transactions or contracts — consistent with single-pass point-read audits being weakest at cross-procedure state reasoning.
4. **Model-only findings still standing unchallenged:** zero `recoveryThreshold` (Claude F5), wildcard cETH mint freeze (DeepSeek F8), initialize front-run window (Claude F6), and recovery-delay pre-elapse (GLM 5.3/OpenAI F11) appear in neither C4 nor the baseline — either genuinely novel or over-rated by models; all warrant sponsor triage.

### What the models found that C4 did not

Ranked by assessed impact:

1. **F10** guardian-brake neutralization (GLM 5.3, High) — escalation of C4's own M-01; corroborated by baseline M-01.
2. **F5** zero `recoveryThreshold` → signature-free owner rotation (Claude).
3. **F4/F12** permanently bricked recovery via SENTINEL owners / survivor collision (3-model consensus / GLM 5.3).
4. **F1** expirationPeriod overflow brick incl. unexecutable repair (ox-alpha + OpenAI consensus).
5. **F2** transient-storage cross-call leak (ox-alpha + Claude consensus).
6. **F7, F8, F9, F11, F6** — Morpho market pinning, cETH freeze, silent 1-of-1 threshold, pre-aged recovery delay, initialize front-run window.

Caveat: these are candidate misses pending sponsor/judge validation; several depend on misconfiguration or multicall patterns C4's judge might rate Low.

### Reliability observations

- **Consensus works:** every multi-model finding (F1, F2, F3, F4, F11) held up under cross-reading and baseline corroboration; no multi-model finding was an obvious false positive.
- **PoC quality varied:** ox-alpha and Claude ran their PoCs (Claude: 8 passing Foundry tests); most others shipped outlines. Executed-PoC models had zero false positives in this run.
- **Coverage claims ≠ depth:** every model claimed full-file coverage; GLM 5.2's empty result and DeepSeek's narrow-but-deep set show coverage lists are weak evidence.
- **Failure mode exists:** a frontier model returning zero findings with full confidence is possible; ensemble runs are necessary, not optional.

### Recommendation

For pre-audit screening of Safe/timelock-class systems: run a heterogeneous ensemble (this exact protocol), weight executed PoCs over outlines, calibrate reported severity against an automated baseline before triage, and treat single-discoverer findings as a queue rather than confirmed. The ensemble surfaced 13 distinct issues where the 27-warden C4 competition surfaced 3 — but only human adjudication separates signal from plausible-looking noise.

# Final Reviewer Comparison — Kleidi Pre-Audit Evaluation

Nine independent reviews of the same snapshot — Kleidi at `0d72b6cb5725c1380212dc76257da96fcfacf22f` (2024-10-17, byte-identical `src/` to the C4 contest repo): one human competition, one automated pipeline, seven LLM agents. This is the closing 3-page summary; raw outputs are under `findings/`, evidence under `primary/`, canonical cross-reference at `findings/CANONICAL.md`.

**Reviewers:** Code4rena (C4, Oct 2024) · Certora baseline (Aug 2026) · GLM 5.3 Flash · DeepSeek v4 · GLM 5.2 · GLM 5.3 · Claude · Codex · v12

---

# Page 1 — Master Comparison Table

| Reviewer | Reported (H/M/L/I) | Valid & corroborated | PoC quality | Signature hit |
| --- | --- | --- | --- | --- |
| **Code4rena** | 0/3/–/– | 3/3 M judge-confirmed | Real PoCs, judge-verified | Calldata index off-by-one (10 duplicate finds) |
| **Certora** | 0/3/10/24 | 3 M + 8 corroborations | Automated, reproducible | Swap-and-pop desync — sole finder |
| **GLM 5.3 Flash** | 0/2/–/– | 2/2 baseline-matched | Executed Foundry tests | `expirationPeriod` overflow brick incl. unexecutable repair |
| **DeepSeek v4** | 0/3/–/– | 2 corroborated | Outlines | Only reviewer (LLM side) to audit the whitelist *configuration* (Morpho/Compound) |
| **GLM 5.2** | 0/2/–/– | 2 corroborated | Outlines with PoC code | Expiration-period _afterCall race + initialize front-run |
| **GLM 5.3** | 1/4/–/– | 4 corroborated | Outlines | Guardian-brake neutralization — the run's only High |
| **Claude** | 0/5/–/– | 3 corroborated | 8 passing Foundry tests | Broadest recovery-path coverage + only full executed suite |
| **Codex** | 0/4/–/– | 4/4 (3 corroborated) | Concrete inline PoCs | Zero false positives; every finding corroborated |
| **v12** | 0/8/–/– | 4 duplicates of known issues, 4 new | Full Foundry PoC per finding | Broadest raw output (8 findings); 4 unique issues not found elsewhere |

**Reading the table:** *Corroborated* = independently matched by Certora and/or C4.

---

# Page 2 — Per-Reviewer Profiles

### Code4rena — the human baseline (Oct 2024)
Three Mediums, all sponsor-confirmed and judge-adjudicated: proposal gas griefing (KLD-001), the calldata index `+1` length bug (KLD-002), and the lowered-`expirationPeriod` execution revert (KLD-003). Its duplicate counts show where human attention concentrated: the calldata whitelist. But the competition entirely missed the recovery-path bricking cluster (SENTINEL owners, survivor collision, zero recovery threshold), the transient-storage leak, the `expirationPeriod` overflow, and the guardian-brake kill. Human breadth was narrow; human depth per finding was the best in the field.

### Certora — the automated baseline (Aug 2026)
Best raw recall among original reviewers (8/21 exact + partials) and the only reviewer to find the swap-and-pop revocation desync (KLD-004) and spell mutual non-exclusivity (KLD-005) — cross-transaction state bugs every other reviewer missed. Its weakness is severity conservatism (zero Highs; rated the pause-OOG brake-kill Medium, the expirationPeriod overflow Informational) and no exploitation narratives. As a calibration reference it is invaluable: every LLM finding that survives Certora cross-checking is real.

### GLM 5.3 Flash
#### Harness: Opencode, Manual Prompting
Two findings, both executed-PoC, both baseline-matched (KLD-006, KLD-015), zero noise. The `expirationPeriod` overflow brick is the sharpest single write-up of the run — including the proof that the repair proposal itself becomes unexecutable. Cost: only two issues surfaced; the recovery contracts went untouched.

### DeepSeek v4
#### Harness: Opencode, Manual Prompting
The only LLM that audited the deployed whitelist configuration rather than only contract logic: unpinned Morpho markets (KLD-011) and the wildcard Compound `mint` (KLD-010), plus the silent 1-of-1 threshold collapse (KLD-017). KLD-011 was reported High and is re-rated Medium here — the attack needs an already-compromised hot key, and Certora rates the config flaw Low. Its blind spot is total: zero findings in the Timelock lifecycle and recovery path.

### GLM 5.2
#### Harness: Opencode, Manual Prompting
Two findings, both corroborated: the `_afterCall` expirationPeriod race (KLD-003) and the initialize front-run (KLD-016). Against the broader finding set across seven other LLMs and two baselines, this is the smallest non-empty contribution, though both findings are real.

### GLM 5.3
#### Harness: Opencode, Manual Prompting
The run's only High: the guardian `pause()` brake can be permanently OOG'd via unbounded proposal flooding with unbounded delays (KLD-001) — a strict escalation of C4's Medium and Certora's Medium. Also the gap-byte weaponization of the overlap off-by-one (KLD-007), and the unique survivor-collision recovery brick (KLD-013). Weaknesses: outline-only PoCs, and it flagged its own uncertainty on KLD-012/KLD-013.

### Claude
#### Harness: Claude Code
Five findings spanning the recovery path (transient leak KLD-015, SENTINEL owners KLD-008, zero `recoveryThreshold` KLD-009, initialize front-run KLD-016) plus the overlap off-by-one (KLD-007). Uniquely validated everything with 8 passing Foundry tests — at the cost of technically violating the read-only constraint. Its negative-results section contains the field's most instructive false negative: it explicitly cleared `BytesHelper.sliceBytes` as sound, which is precisely where C4's KLD-002 lived.

### Codex
#### Harness: Codex
Four findings (expiration overflow KLD-006, SENTINEL owners KLD-008, recovery-delay pre-elapse KLD-012, failed Safe-module calls KLD-014), every one corroborated, zero false positives, concrete inline PoCs. The trade-off is breadth: the smallest non-empty issue surface among the original six, no lifecycle or configuration depth.

### v12
Eight findings with full Foundry PoCs — the largest raw output of any single LLM. Four are duplicates of known canonical issues (KLD-001, KLD-003, KLD-006, KLD-007), confirming them independently. Four are new: paused-batch callback escape (KLD-019), zero-guardian deployment (KLD-018), hot-signer lifecycle independence (KLD-020), and pause-predicate sentinel edge case (KLD-021). The new findings range from Low (KLD-018, KLD-019) to Informational (KLD-020, KLD-021) — the latter two are design observations rather than bugs. Severity calibration shows the same +1 notch inflation pattern: all 8 findings were reported Medium, but 4 normalize lower.

---

# Page 3 — Accuracy Analysis

### Canonical issue set (21)

Union of all reviews after dedup: **21 distinct issues** identified by canonical `KLD-NNN` identifiers. See `findings/CANONICAL.md` for the full master table, cross-reference, and methodology.

**Distribution:** 1 High · 13 Medium · 5 Low · 2 Informational

### Issue × reviewer coverage matrix

Legend: **+** = found · **~** = partial (adjacent/subsystem match or corroboration entry) · **.** = missed.

| KLD | Issue | C4 | Certora | GLM 5.3 Flash | DeepSeek | GLM 5.2 | GLM 5.3 | Claude | Codex | v12 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 001 | Guardian pause permanently killable | + | + | . | . | . | + | . | . | + |
| 002 | Index +1 length bug in sliceBytes | + | . | . | . | . | ~ | ~ | . | . |
| 003 | _afterCall re-checks post-execution expirationPeriod | + | . | . | . | + | . | . | . | + |
| 004 | Swap-and-pop revocation desync | . | + | . | . | . | . | . | . | . |
| 005 | Recovery spell mutual non-exclusivity | . | + | . | . | . | . | . | . | . |
| 006 | expirationPeriod overflow bricks governance | . | ~ | + | . | . | . | . | + | + |
| 007 | Off-by-one in calldata-check overlap | . | ~ | . | . | . | + | + | . | + |
| 008 | SENTINEL/Safe-address owners brick recovery | . | ~ | . | . | . | + | + | + | . |
| 009 | Zero recoveryThreshold unauthorized recovery | . | . | . | . | . | . | + | . | . |
| 010 | Wildcard cETH mint freezes native balance | . | . | . | + | . | . | . | . | . |
| 011 | Unpinned Morpho markets enable drain | . | ~ | . | + | . | . | . | . | . |
| 012 | Recovery delay pre-elapses before enablement | . | . | . | . | . | + | . | + | . |
| 013 | Survivor-collision bricks recovery rotation | . | ~ | . | . | . | + | . | . | . |
| 014 | Failed Safe-module calls recorded as executed | . | ~ | . | . | . | . | . | + | . |
| 015 | Transient storage leak in RecoverySpellFactory | . | + | + | . | . | . | + | . | . |
| 016 | Initialize front-run on direct factory use | . | . | . | . | + | . | + | . | . |
| 017 | 1-of-1 wallet for single-owner instances | . | ~ | . | + | . | . | . | . | . |
| 018 | Zero guardian disables pause at deployment | . | . | . | . | . | . | . | . | + |
| 019 | Paused batch continues after callback | . | . | . | . | . | . | . | . | + |
| 020 | Hot signers not revoked on owner removal | . | . | . | . | . | . | . | . | + |
| 021 | Pause predicate ignores zero sentinel | . | . | . | . | . | . | . | . | + |

### Scoreboard

| Metric | Leader | Detail |
| --- | --- | --- |
| Raw recall | **Certora & v12 (tie, 8/21, 38%)** | GLM 5.3 & Claude tie for best among original LLMs at 5/21 (24%); C4 itself only 3/21 exact (14%) |
| Precision | **C4 (judge-confirmed 3/3)**; among LLMs: Codex & GLM 5.3 Flash (0 false positives) | v12 has 2 Informational-grade findings that are design observations rather than bugs |
| PoC rigor | **Claude** (8 executed tests), v12 (8 executed tests), & GLM 5.3 Flash (executed) | C4's PoCs were judge-verified; Certora's are machine-reproducible |
| Severity realism | **Certora** (calibrated) | LLMs inflate +1 to +2 notches on average; DeepSeek worst (+1.5–2, incl. the KLD-011 High) |
| Unique value | **Certora** (KLD-004, KLD-005) · **Claude** (KLD-009) · **DeepSeek** (KLD-010, config audit) · **GLM 5.3** (KLD-001 escalation, KLD-013) · **v12** (KLD-018, KLD-019) | Each found issues nobody else did |
| Reliability | **Everyone except GLM 5.2** | GLM 5.2 produced findings but the fewest of any non-empty reviewer |

### Final ranking (LLM field)

1. **v12** — highest raw recall (tied with Certora at 8/21), 4 unique findings, full PoCs. Weakened by severity inflation (+1 notch across the board) and 2 Informational-grade design observations reported as Medium.
2. **GLM 5.3 & Claude (tie)** — GLM 5.3 takes the only High and the best exploit chains; Claude matches its recall with executed tests and broader recovery coverage. Pick per need: exploits vs. verification.
3. **Codex** — perfect precision, but one finding short of the leaders' surface coverage.
4. **DeepSeek v4** — irreplaceable config-level lens, blind elsewhere, loosest severity.
5. **GLM 5.3 Flash** — flawless on what it covered, minimal volume.
6. **GLM 5.2** — smallest non-empty contribution.

### Verdict

No single reviewer dominated. The human competition had the best per-finding confidence and the worst coverage of modern concerns; the automated pipeline had the best recall and the flattest severity; the LLMs sat between — strong on exploit narrative, weak on cross-transaction state reasoning (all seven missed both Certora-exclusive Mediums), and prone to +1-notch inflation. The practical protocol this evaluation supports: **LLM ensemble for breadth → automated baseline for calibration → human/judge time only on the intersection and the survivors.** Applied here, that funnel would have surfaced 21 issues — including 10 the original 27-warden C4 contest never saw — at a fraction of contest cost.

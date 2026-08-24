# Final Reviewer Comparison — Kleidi Pre-Audit Evaluation

Eight independent reviews of the same snapshot — Kleidi at `0d72b6cb5725c1380212dc76257da96fcfacf22f` (2024-10-17, byte-identical `src/` to the C4 contest repo): one human competition, one automated pipeline, six LLM agents. This is the closing 3-page summary; raw outputs are under `findings/`, evidence under `primary/`.

**Reviewers:** Code4rena (C4, Oct 2024) · Certora baseline (Aug 2026) · ox-alpha · DeepSeek v4 · GLM 5.2 · GLM 5.3 · Claude · Codex

---

# Page 1 — Master Comparison Table

| Reviewer | Type | Reported (H/M/L/I) | Valid & corroborated | Recall /17 | Severity drift | PoC quality | Signature hit | Worst blind spot |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Code4rena** | Human contest, 27 wardens | 0/3/–/11 QA | 3/3 M judge-confirmed | **3** (+3 near-misses) | reference (judge-adjudicated) | Real PoCs, judge-verified | Calldata index off-by-one (10 duplicate finds) | Missed the entire recovery-bricking cluster; missed pause-OOG escalation |
| **Certora** | Automated pipeline | 0/3/10/24 | 3 M + 7 corroborations | **10** | reference calibration | Automated, reproducible | Swap-and-pop desync — sole finder | Zero Highs; rated the pause-OOG brake-kill only Medium |
| **ox-alpha** | LLM, executed PoCs | 0/2/–/– | 2/2 baseline-matched | **2** | +1.5 notches | Executed Foundry tests | `expirationPeriod` overflow brick incl. unexecutable repair | Low volume; recovery path untouched |
| **DeepSeek v4** | LLM | 1/2 → re-rated 0/3 | 2 corroborated, 1 unchallenged | **3** | +1.5–2 | Outlines | Only reviewer (LLM side) to audit the whitelist *configuration* (Morpho/Compound) | Nothing on Timelock lifecycle or recovery path |
| **GLM 5.2** | LLM | none | — | **0** | n/a | none | — | Empty report despite claiming full coverage |
| **GLM 5.3** | LLM | 1/4/–/– | 4 corroborated, 1 unchallenged | **5** | +1 | Outlines | Guardian-brake neutralization — the run's only High | PoCs never executed; self-doubt on F11/F12 |
| **Claude** | LLM, executed PoCs | 0/5/–/– | 3 corroborated, 2 unchallenged | **5** | +1 | 8 passing Foundry tests | Broadest recovery-path coverage + only full executed suite | False negative: explicitly cleared `sliceBytes` — C4 M-02's exact home |
| **Codex** | LLM | 0/3/–/– | 3/3 (2 corroborated, 1 unchallenged) | **3** | +1.5 | Concrete inline PoCs | Zero false positives; every finding corroborated or unchallenged | Narrowest non-empty surface (3 issues, no lifecycle/config depth) |

**Reading the table:** *Recall /17* = share of the 17 canonical issues hit (defined on Page 3). *Severity drift* = average notch inflation vs. the Certora rating where both reviewed the same issue. *Corroborated* = independently matched by Certora and/or C4; *unchallenged* = not contradicted by any other review.

---

# Page 2 — Per-Reviewer Profiles

### Code4rena — the human baseline (Oct 2024)
Three Mediums, all sponsor-confirmed and judge-adjudicated: proposal gas griefing (M-01), the calldata index `+1` length bug (M-02, 10 duplicate finders), and the lowered-`expirationPeriod` execution revert (M-03). Its duplicate counts show where human attention concentrated: the calldata whitelist. But the competition entirely missed the recovery-path bricking cluster (SENTINEL owners, survivor collision, zero recovery threshold), the transient-storage leak, the `expirationPeriod` overflow, and the guardian-brake kill. Human breadth was narrow; human depth per finding was the best in the field.

### Certora — the automated baseline (Aug 2026)
Best raw recall (10/17) and the only reviewer to find the swap-and-pop revocation desync — a cross-transaction state bug every other reviewer missed. Its weakness is severity conservatism (zero Highs; rated the guardian-brake kill Medium) and no exploitation narratives. As a calibration reference it is invaluable: every LLM finding that survives Certora cross-checking is real.

### ox-alpha — small, exact
Two findings, both executed-PoC, both baseline-matched (F1→I-01, F2→L-05), zero noise. The `expirationPeriod` overflow brick is the sharpest single write-up of the run — including the proof that the repair proposal itself becomes unexecutable. Cost: only two issues surfaced; the recovery contracts went untouched.

### DeepSeek v4 — the config auditor
The only LLM that audited the deployed whitelist configuration rather than only contract logic: unpinned Morpho markets and the wildcard Compound `mint` (F7, F8), plus the silent 1-of-1 threshold collapse (F9). F7 was reported High and is re-rated Medium here — the attack needs an already-compromised hot key, and Certora rates the config flaw Low. Its blind spot is total: zero findings in the Timelock lifecycle and recovery path.

### GLM 5.2 — the empty report
Full coverage claimed, zero findings delivered, no explanation. Against twelve sibling findings across five other LLMs, this is a hard failure of the audit task, not a judgment that the code was clean.

### GLM 5.3 — the exploit engineer
The run's only High: the guardian `pause()` brake can be permanently OOG'd via unbounded proposal flooding with unbounded delays (F10) — a strict escalation of C4's M-01 and Certora's M-01. Also the gap-byte weaponization of the overlap off-by-one (F3), and the unique survivor-collision recovery brick (F12). Weaknesses: outline-only PoCs, and it flagged its own uncertainty on F11/F12.

### Claude — the thorough one with one bad clear
Five findings spanning the recovery path (transient leak, SENTINEL owners, zero `recoveryThreshold`, initialize front-run window) plus the overlap off-by-one. Uniquely validated everything with 8 passing Foundry tests — at the cost of technically violating the read-only constraint. Its negative-results section contains the field's most instructive false negative: it explicitly cleared `BytesHelper.sliceBytes` as sound, which is precisely where C4's M-02 lived.

### Codex — the precision play
Three findings (expiration overflow variant, SENTINEL owners, recovery-delay pre-elapse), every one corroborated or unchallenged, zero false positives, concrete inline PoCs. The trade-off is breadth: the smallest non-empty issue surface, no lifecycle or configuration depth.

---

# Page 3 — Accuracy Analysis

### Canonical issue set (17)

Union of all reviews after dedup: **12 model issues (F1–F12)** + **2 Certora-exclusive Mediums** (swap-and-pop desync; spell mutual non-exclusivity) + **3 C4 Mediums** (gas griefing; index `+1` bug; lowered-expiration revert). C4's 11 low/QA items and Certora's remaining L/I are excluded from recall math except where they corroborate a canonical issue.

### Issue × reviewer coverage matrix

Legend: **✓** = found · **✓✓** = found with duplicates · **◐** = partial (adjacent/subsystem match or corroboration entry) · **·** = missed.

| # | Issue | C4 | Certora | ox-alpha | DeepSeek | GLM 5.2 | GLM 5.3 | Claude | Codex |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | C4-M1 proposal gas griefing | ✓✓ | ◐ M-01 escalated | · | · | · | ◐ F10 escalated | · | · |
| 2 | C4-M2 index `+1` length bug | ✓✓ | · | · | · | · | ◐ F3 same subsystem | ◐ F3 same subsystem, FN on sliceBytes | · |
| 3 | C4-M3 lowered-expiration revert | ✓✓ | · | ◐ F1 same variable | · | · | · | · | ◐ F1 same variable |
| 4 | F1 expirationPeriod overflow brick | · | ◐ I-01 | ✓ | · | · | · | · | ✓ |
| 5 | F2 transient storage leak | · | ◐ L-05 | ✓ | · | · | · | ✓ | · |
| 6 | F3 overlap strict-inequality off-by-one | · | ◐ L-02 | · | · | · | ✓ | ✓ | · |
| 7 | F4 SENTINEL owners brick recovery | · | ◐ L-09 | · | · | · | ✓ | ✓ | ✓ |
| 8 | F5 zero `recoveryThreshold` | · | · | · | · | · | · | ✓ | · |
| 9 | F6 initialize front-run window | · | · | · | · | · | · | ✓ | · |
| 10 | F7 unpinned Morpho markets | · | ◐ L-01 | · | ✓ | · | · | · | · |
| 11 | F8 wildcard cETH mint freeze | · | · | · | ✓ | · | · | · | · |
| 12 | F9 single-owner threshold bypass | · | ◐ I-05 | · | ✓ | · | · | · | · |
| 13 | F10 guardian pause() OOG kill | · | ✓ M-01 | · | · | · | ✓ | · | · |
| 14 | F11 recovery delay pre-elapse | · | · | · | · | · | ✓ | · | ✓ |
| 15 | F12 survivor-collision recovery brick | · | ◐ L-07 | · | · | · | ✓ | · | · |
| 16 | B-M2 swap-and-pop desync | · | ✓ | · | · | · | · | · | · |
| 17 | B-M3 spell mutual non-exclusivity | · | ✓ | · | · | · | · | · | · |

### Scoreboard

| Metric | Leader | Detail |
| --- | --- | --- |
| Raw recall | **Certora (10/17, 59%)** | GLM 5.3 & Claude tie for best LLM at 5/17 (29%); C4 itself only 3/17 exact (18%) |
| Precision | **C4 (judge-confirmed 3/3)**; among LLMs: Codex & ox-alpha (0 false positives) | No reviewer contradicted another's confirmed finding anywhere in the run |
| PoC rigor | **Claude** (8 executed tests) & ox-alpha (executed) | C4's PoCs were judge-verified; Certora's are machine-reproducible |
| Severity realism | **Certora** (calibrated) | LLMs inflate +1 to +2 notches on average; DeepSeek worst (+1.5–2, incl. the F7 High) |
| Unique value | **Certora** (swap-and-pop, spell non-exclusivity) · **Claude** (F5, F6) · **DeepSeek** (F8, config audit) · **GLM 5.3** (F10 escalation, F12) | Each of the four found issues nobody else did |
| Reliability | **Everyone except GLM 5.2** | GLM 5.2's empty report is the run's cautionary tale: silent failure is a real LLM-auditor mode |

### Final ranking (LLM field)

1. **GLM 5.3 & Claude (tie)** — GLM 5.3 takes the only High and the best exploit chains; Claude matches its recall with executed tests and broader recovery coverage. Pick per need: exploits vs. verification.
2. **Codex** — perfect precision, but half the surface coverage of the leaders.
3. **DeepSeek v4** — irreplaceable config-level lens, blind elsewhere, loosest severity.
4. **ox-alpha** — flawless on what it covered, minimal volume.
5. **GLM 5.2** — did not participate, effectively.

### Verdict

No single reviewer dominated. The human competition had the best per-finding confidence and the worst coverage of modern concerns; the automated pipeline had the best recall and the flattest severity; the LLMs sat between — strong on exploit narrative, weak on cross-transaction state reasoning (all six missed both Certora-exclusive Mediums), and prone to +1-notch inflation. The practical protocol this evaluation supports: **LLM ensemble for breadth → automated baseline for calibration → human/judge time only on the intersection and the survivors.** Applied here, that funnel would have surfaced 17 issues — including 9 the original 27-warden C4 contest never saw — at a fraction of contest cost.

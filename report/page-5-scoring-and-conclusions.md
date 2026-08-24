# Page 5 — Scoring vs. C4 Ground Truth & Conclusions

## Coverage of the three C4 Mediums

| C4 finding | Reproduced exactly? | Nearest model result |
| --- | --- | --- |
| **M-01** proposal gas griefing vs. defense cost | No — but **exceeded**: GLM 5.3's F10 shows `pause()` can be made *permanently* OOG (unbounded delays prevent expiry/cleanup), converting griefing into full brake neutralization | GLM 5.3 F10 (High) |
| **M-02** off-by-one in index length (`end - start` missing `+1`) → whitelisted calls revert | No model stated the `+1` length bug as such; Claude & GLM 5.3 found the *inverse* symptom in the same subsystem — strict-inequality overlap check rejecting valid adjacent ranges, with GLM 5.3 weaponizing the resulting unchecked gap byte | Claude F3, GLM 5.3 F3 |
| **M-03** readiness re-check uses newly-lowered `expirationPeriod` → update unexecutable | No — but ox-alpha & OpenAI found a different, arguably worse flaw in the same variable: unbounded upper bound → arithmetic overflow bricks all execution including repair proposals | ox-alpha F1, OpenAI F2 |

**Score: 0/3 exact reproductions, but substantive near-miss coverage on 3/3** — each model-cluster landed on the same subsystem C4's wardens flagged, via different defects. This suggests LLM auditors reliably find "where," less reliably "what exactly."

## What the models found that C4 did not

Ranked by assessed impact:

1. **F7** Morpho market-pinning gap (DeepSeek v4, High) — compromised-hot-signer total collateral drain.
2. **F10** guardian-brake neutralization (GLM 5.3, High) — escalation of C4's own M-01.
3. **F5** zero `recoveryThreshold` → signature-free owner rotation (Claude).
4. **F4/F12** permanently bricked recovery via SENTINEL owners / survivor collision (3-model consensus / GLM 5.3).
5. **F1** expirationPeriod overflow brick incl. unexecutable repair (ox-alpha + OpenAI consensus).
6. **F2** transient-storage cross-call leak (ox-alpha + Claude consensus).
7. **F8, F9, F11, F6** — cETH freeze, silent 1-of-1 threshold, pre-aged recovery delay, initialize front-run window.

Caveat: these are candidate misses pending sponsor/judge validation; several depend on misconfiguration or multicall patterns C4's judge might rate Low.

## Comparison with the Certora automated audit review

The Certora baseline (2026-08-22, same commit, independent automated pipeline: 0 High / 3 Medium / 10 Low / 24 Info — see `primary/certora-baseline/`) provides a second modern reference frame. Cross-referencing every baseline entry against the model outputs:

| Baseline finding | Sev | Matching model result | Agreement |
| --- | --- | --- | --- |
| M-01 Unbounded `pause()` loop → guardian permanently disabled by gas griefing | M | **GLM 5.3 F10** (rated **High**) | Exact match; models rated higher |
| M-02 Swap-and-pop removal indices desync queued revocations → wrong check deleted | M | — | **Missed by all six models** |
| M-03 Recovery spells mutually non-exclusive; recovered owners cannot disable other spells | M | — (F11 delay-pre-elapse is an adjacent but distinct defect) | **Missed by all six models** |
| L-01 Morpho documented policies/configs allow asset drain | L | DeepSeek v4 F7 (rated **High**) | Match; models rated higher |
| L-02 Strict inequality blocks contiguous calldata checks | L | Claude F3 + GLM 5.3 F3 (rated Medium) | Exact match |
| L-05 Transient storage pollution breaks batch deploy composability | L | ox-alpha F2 + Claude F2 (rated Medium) | Exact match |
| L-07 Recovery fails when first replacement owner is the retained current owner | L | GLM 5.3 F12 (rated Medium) | Exact match |
| L-09 Inadequate owner-address validation bricks wallets | L | Claude/GLM 5.3/OpenAI F4 (SENTINEL owners, rated Medium) | Partial match |
| I-01 Unbounded delays/expiration periods → arithmetic overflow brick | I | ox-alpha F1 + OpenAI F2 (rated Medium) | Exact match |
| I-05 Single-owner setups silently bypass requested threshold | I | DeepSeek v4 F9 (rated Medium) | Exact match |

### Takeaways

1. **7 of the models' 13 distinct findings are independently corroborated by the baseline**, including both of the run's most consequential claims (guardian-brake neutralization, Morpho market drain). Zero model findings were flatly contradicted by the baseline.
2. **Systematic severity divergence:** for every corroborated issue the baseline rates one-to-two notches lower than the models (High→M/L, Medium→L/I). The models optimize for impact narratives; the calibrated pipeline discounts exploitability preconditions.
3. **The two baseline Mediums that every model missed share a profile:** stateful lifecycle bugs (queued-revocation index drift, multi-spell interaction) that span multiple transactions or contracts — consistent with single-pass point-read audits being weakest at cross-procedure state reasoning.
4. **Model-only findings still standing unchallenged:** zero `recoveryThreshold` (Claude F5), wildcard cETH mint freeze (DeepSeek F8), initialize front-run window (Claude F6), and recovery-delay pre-elapse (GLM 5.3/OpenAI F11) appear in neither C4 nor the baseline — either genuinely novel or over-rated by models; all warrant sponsor triage.

## Reliability observations

- **Consensus works:** both multi-model findings (F1, F2, F3, F4, F11) held up under cross-reading; no multi-model finding was an obvious false positive.
- **PoC quality varied:** ox-alpha and Claude ran their PoCs (Claude: 8 passing Foundry tests); most others shipped outlines. Executed-PoC models had zero false positives in this run.
- **Coverage claims ≠ depth:** every model claimed full-file coverage; GLM 5.2's empty result and DeepSeek's narrow-but-deep set show coverage lists are weak evidence.
- **Failure mode exists:** a frontier model returning zero findings with full confidence is possible; ensemble runs are necessary, not optional.

## Recommendation

For pre-audit screening of Safe/timelock-class systems: run a heterogeneous ensemble (this exact protocol), weight executed PoCs over outlines, and treat single-discoverer High findings as triage queue rather than confirmed. The ensemble surfaced 13 distinct issues where the 27-warden C4 competition surfaced 3 — but only human adjudication separates signal from plausible-looking noise.

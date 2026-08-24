# Page 4 — Model-by-Model Analysis

## GLM 5.3 — 5 findings (1 High, 4 Medium) — strongest overall

- **F10 (High):** Only model to show the guardian brake itself can be *neutralized*: unbounded `_liveProposals` + unbounded per-proposal delay → `pause()` always OOGs, then the malicious proposal executes permissionlessly. This is a strict escalation of C4 M-01 (which only argued cost asymmetry).
- **F3:** Same overlap off-by-one as Claude's, plus a concrete exploit through the forced gap byte (MSB of `amount` tampered → ~2^248 transfer).
- **F4, F11, F12:** Recovery-path trio; F12 (survivor-collision `swapOwner(SENTINEL, alice, alice)`) is unique to this model and not in the C4 report.
- Weakness: F11/F12 confidence self-rated Medium; PoCs are outlines rather than executed tests.

## Claude — 5 findings (0 High, 5 Medium) — broadest recovery-path coverage

*Post-run update:* Claude's polished artifact report confirms all five PoCs were validated with **8 runnable Foundry tests (`test/unit/AuditFindings.t.sol`, 407 lines) — all passing** against unmodified source. This upgrades its PoC quality to "executed" and adds an explicit negative-results section (areas cleared). Two caveats: (a) writing the test file technically deviated from the read-only instruction; (b) its negative results include one notable **false negative** — it explicitly cleared `BytesHelper.sliceBytes` as "correctly validating bounds," which is precisely where C4's M-02 off-by-one lived.

- **F2** transient-storage leak found independently of ox-alpha (consensus signal).
- **F3** overlap off-by-one — but its PoC assumes end-exclusive range semantics; audited code's `sliceBytes` treats ranges inclusively (the very confusion behind C4 M-02). The observed rejection of adjacent ranges is nonetheless real behavior, and matches the issue the team actually fixed post-audit (`d2df6ba` "allow end and start index to overlap for single byte").
- **F4, F5:** SENTINEL owners and the asymmetric `threshold` vs `recoveryThreshold` validation gap — F5 is unique to Claude and plausibly High in impact.
- **F6 (Low confidence):** front-runnable `initialize` on direct factory deployments — real pattern, but the system's documented flow always initializes atomically; correctly self-rated Low confidence.

## DeepSeek v4 — 3 findings (1 High, 2 Medium) — most attacker-economics-driven

- **F7 (High, the run's top-severity finding):** only model to audit the *whitelist configuration* rather than just contract code: unpinned Morpho `MarketParams` on `supplyCollateral`/`borrow` → compromised hot signer posts collateral into a self-created market and liquidates it. Full end-to-end chain including `createMarket` permissionlessness.
- **F8:** wildcard Compound `mint` + unchecked `value` → whole native balance locked in cETH with no whitelisted exit; cites the project's own EDGECASES.md requirement.
- **F9:** silent threshold collapse to 1-of-1 for single-owner instances.
- Weakness: no findings in the Timelock lifecycle/recovery path; coverage claims full sweep.

## OpenAI — 3 findings (0 High, 3 Medium) — precise but narrow

- **F1, F4, F11:** one Timelock overflow variant, and consensus hits on both recovery issues.
- All three PoCs are concrete and correct in shape; zero false positives in the set.
- Weakness: no novel single-discoverer issues; smallest distinct-issue surface among non-empty reporters.

## ox-alpha — 2 findings (0 High, 2 Medium) — small but high-quality

- **F1:** unbounded `expirationPeriod` overflow brick with an executed Foundry PoC, including the nasty detail that the *repair proposal* itself becomes unexecutable.
- **F2:** transient-storage leak, executed PoC, and the downstream consequence chain (dead counterfactual module enabled as Safe module).
- Both findings executed-and-passing tests rather than outlines; zero false positives. Low volume is the main cost.

## GLM 5.2 — 0 findings — failed run

Returned only a coverage list. No findings, no errors, no explanation. Either the model judged the codebase clean (contradicted by 12 sibling findings) or failed to emit structured output. Excluded from quality scoring; a reliability data point in its own right.

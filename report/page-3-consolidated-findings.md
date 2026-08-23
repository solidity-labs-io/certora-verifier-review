# Page 3 — Consolidated Findings Matrix

13 distinct issues after deduplication. "✓" = model reported the issue. Severity shown is each reporter's own rating (H = High, M = Medium).

| # | Issue (short) | Location | Sev | ox-alpha | Claude | DeepSeek v4 | GLM 5.3 | OpenAI |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | Unbounded `expirationPeriod` → checked-arithmetic overflow permanently bricks execute/cleanup incl. repair proposals | Timelock.sol L289/L972, L399 | M | ✓ | | | | | ✓ |
| F2 | Transient `tstore` duplicate-owner flags leak across calls → batched `createRecoverySpell` reverts; dead counterfactual modules | RecoverySpellFactory.sol L58–71 | M | ✓ | ✓ | | | |
| F3 | Overlap check uses strict inequalities on half-open ranges → adjacent parameter checks rejected; forced gap leaves unchecked bytes exploitable by hot signer | Timelock.sol L1119–1123 | M | | ✓ | | ✓ | |
| F4 | SENTINEL `address(1)` (and Safe itself) accepted as recovery owner → `executeRecovery` always reverts GS013/GS203, recovery permanently bricked | RecoverySpellFactory.sol L135–137 | M | | ✓ | | ✓ | ✓ |
| F5 | Zero `recoveryThreshold` accepted → `executeRecovery` with zero signatures rotates all owners | RecoverySpellFactory.sol L118–138 | M | | ✓ | | | |
| F6 | `initialize()` unguarded beyond one-shot flag → front-runnable on directly-deployed timelocks (low confidence) | Timelock.sol L316–329 | M | | ✓ | | | |
| F7 | Morpho whitelist does not pin `MarketParams` for `supplyCollateral`/`borrow` → compromised hot signer drains collateral via attacker-created market + liquidation | Timelock.sol L475–504, L715–755 | H | | | ✓ | | |
| F8 | Wildcard Compound `mint` `[4,4)` + unchecked `msg.value` → hot signer freezes entire native balance with no whitelisted exit | Timelock.sol L488–493 | M | | | ✓ | | |
| F9 | Single-owner instances silently deploy threshold-1 regardless of requested `threshold` | InstanceDeployer.sol L315–328 | M | | | ✓ | | |
| F10 | Guardian `pause()` iterates unbounded `_liveProposals` set; junk proposals with unbounded delays make pause permanently OOG → emergency brake neutralized | Timelock.sol L687–700, L521–539 | H | | | | ✓ | |
| F11 | Recovery delay clock starts at permissionless spell deployment, not module enablement → delay window can be pre-aged cross-chain | RecoverySpell.sol L124 | M | | | | ✓ | ✓ |
| F12 | `executeRecovery` reverts forever when spell `owners[0]` equals the surviving oldest Safe owner ("keep primary" config) | RecoverySpell.sol L259–273 | M | | | | ✓ | |
| — | *GLM 5.2* | — | — | | | | | *(no findings)* |

## Attribution notes

- F1: two independent discoveries with materially different PoCs (overflow brick vs. constructor-time max period).
- F3: both reporters converge on the strict-inequality off-by-one; GLM 5.3 additionally builds the full exploit chain through the forced gap byte (`2^248` amount tampering).
- F4: three-model consensus, strongest signal in the run.
- F11: two-model consensus with independent framing (cross-chain front-run vs. compromised recovery quorum).
- F2, F10, F12, F5, F7, F8, F9, F6: single-discoverer candidates.

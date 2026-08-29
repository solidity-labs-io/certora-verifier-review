## [Medium] Unbounded `expirationPeriod` lets one executed proposal permanently brick all timelock execution
> **KLD-006** · Normalized: Medium
- File: src/Timelock.sol:L972-L977 (also src/Timelock.sol:L399-L404, L413-L422)
- Severity: Medium
- Confidence: High
- Description: `updateExpirationPeriod` only enforces `newPeriod >= MIN_DELAY`, unlike every other tunable (`minDelay`, `pauseDuration`), which is bounded above. `isOperationReady` and `isOperationExpired` compute `timestamp + expirationPeriod` in checked arithmetic; once `expirationPeriod` is set close to `2^256`, that sum overflows (Panic 0x11) for any proposal scheduled afterwards, so `execute`/`executeBatch`/`cleanup` revert forever — including the repair proposal that would reset the value.
- Attack scenario: 1. Coerced/malicious safe owner schedules two operations: `P_exit` (any action, delay D2) and `P_brick` targeting the timelock with `updateExpirationPeriod(X)` where `X = 2^256 - 1 - timestamps(P_exit)`, delay D1 < D2. 2. At D1 anyone executes `P_brick`; its own readiness checks don't overflow because `timestamps(P_brick) < timestamps(P_exit)`. 3. At D2 `P_exit` still executes (its sum equals `2^256 - 1`). 4. From then on, every newly scheduled operation can be proposed by honest owners but can never be executed or cleaned up; `pause()`/guardian/signer rotation cannot repair it. All timelock-held funds are permanently frozen except previously whitelisted hot-signer paths, and there is no recovery path, even for full legitimate owner control.
- PoC: Foundry test (executed, passes): deploy `Timelock(safe=this, 1 days, 30 days, guardian, 10 days, [])`; warp to realistic time; `schedule(exitTarget, 0, "", 0, 2 days)`; read `tsExit = timestamps(exitId)`; `schedule(timelock, 0, abi.encodeWithSelector(Timelock.updateExpirationPeriod.selector, type(uint256).max - tsExit), 0, 1 days)`; warp +1 day, `execute(...)` brick -> succeeds; warp +1 day, `execute(exit...)` -> succeeds; `schedule(this, 0, anyData, 0, 1 days)`, warp past ready/expiry -> `execute(...)` reverts `Panic(0x11)`, `cleanup(id)` reverts `Panic(0x11)`, and executing a freshly scheduled `updateExpirationPeriod(30 days)` repair also reverts `Panic(0x11)`.

## [Medium] Transient duplicate-owner check leaks across calls, breaking batched RecoverySpell deployments
> **KLD-015** · Normalized: Low
- File: src/RecoverySpellFactory.sol:L58-L71
- Severity: Medium
- Confidence: High
- Description: `createRecoverySpell` flags each owner address with `tstore(owner, 1)` and never clears the flags. Transient storage lives for the entire transaction, so any later `createRecoverySpell` call in the same transaction whose owner list shares even one address with an earlier call reverts with "Duplicate owner", although each spell individually has unique owners. `calculateAddress` (src/RecoverySpellFactory.sol:L96-L103) implements the same check per-call instead, confirming uniqueness was meant to be scoped to a single spell.
- Attack scenario: 1. User batch-deploys several recovery spells that share a recovery member (e.g., a social-recovery spell and a dead-man-switch spell) via `Multicall3.aggregate3` in one transaction, as the multi-spell `InstanceDeployer` flow implies. 2. With `allowFailure = false` the whole deployment reverts; with `allowFailure = true` the second creation silently fails. 3. The user then enables the predicted-but-never-deployed spell address as a Safe module (`enableModule` does not check for code), leaving a dead emergency-recovery module: on key loss `executeRecovery` cannot run and timelock-held funds are inaccessible.
- PoC: Foundry test (executed, passes): within one transaction call `factory.createRecoverySpell(bytes32(1), [A, B], safe, 1, 1, 1 days)` followed by `factory.createRecoverySpell(bytes32(2), [A, C], safe, 1, 1, 1 days)`; the second call reverts `"RecoverySpell: Duplicate owner"`. Issuing the identical two calls in separate transactions succeeds, proving state leaks across calls rather than bad parameters.

## Coverage
- src/Timelock.sol — reviewed
- src/ConfigurablePause.sol — reviewed
- src/Guard.sol — reviewed
- src/InstanceDeployer.sol — reviewed
- src/RecoverySpell.sol — reviewed
- src/RecoverySpellFactory.sol — reviewed
- src/TimelockFactory.sol — reviewed
- src/BytesHelper.sol — reviewed
- src/utils/Constants.sol — reviewed
- src/utils/Create2Helper.sol — reviewed
- src/views/AddressCalculation.sol — reviewed
- src/interface/IMulticall3.sol — reviewed
- src/interface/IMorpho.sol — reviewed
- src/interface/WETH9.sol — reviewed
- src/interface/CErc20Interface.sol — reviewed
- src/interface/CEtherInterface.sol — reviewed
- src/deploy/SystemDeploy.s.sol — reviewed

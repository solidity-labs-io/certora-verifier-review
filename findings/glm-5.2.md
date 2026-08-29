## [Medium] `_afterCall` uses post-execution `expirationPeriod`, permanently locking governance proposals that decrease it
> **KLD-003** · Normalized: Medium

- File: src/Timelock.sol:1009-1015, src/Timelock.sol:399-404, src/Timelock.sol:972-977
- Severity: Medium
- Confidence: High
- Description: `_afterCall(id)` calls `isOperationReady(id)` **after** the external call executes. `isOperationReady` reads the **current** `expirationPeriod` storage variable (line 403), not the value that was in effect when the proposal was scheduled. If the proposal's execution decreases `expirationPeriod` (via `updateExpirationPeriod`), `_afterCall` validates against the new, smaller value. If the elapsed time since the proposal became ready exceeds the new `expirationPeriod`, the check fails and the entire `execute()` reverts. The proposal remains in `_liveProposals` and is "ready" under the old expiration window, but every execution attempt reverts identically — the proposal is permanently stuck and can only be cancelled.
- Attack scenario:
  1. `expirationPeriod` is 30 days. Safe schedules a proposal to call `updateExpirationPeriod(1 days)` with `delay = MIN_DELAY` (1 day).
  2. At `T + 1 day`, the proposal becomes ready (`isOperationReady` returns true under the 30-day window).
  3. At `T + 3 days` (within the 30-day window), anyone calls `execute()`.
  4. `_execute` succeeds, setting `expirationPeriod = 1 day` mid-execution.
  5. `_afterCall` checks `isOperationReady(id)`: `timestamps[id] + 1 day > T + 3 days` → `(T+1day) + 1day > T+3days` → `T+2days > T+3days` → **false**.
  6. `_afterCall` reverts, rolling back the entire `execute()`. `expirationPeriod` is restored to 30 days, the proposal is back in `_liveProposals`.
  7. Every subsequent execution attempt fails identically. The proposal cannot be executed — only cancelled by the Safe.
- PoC:
```solidity
function testAfterCallExpirationRevert() public {
    // Start with 30-day expiration
    vm.prank(address(timelock));
    timelock.updateExpirationPeriod(30 days);

    // Schedule proposal to decrease expiration to 1 day
    bytes memory payload = abi.encodeWithSelector(
        timelock.updateExpirationPeriod.selector, 1 days
    );
    vm.prank(address(safe));
    timelock.schedule(address(timelock), 0, payload, bytes32(0), MINIMUM_DELAY);

    bytes32 id = timelock.hashOperation(address(timelock), 0, payload, bytes32(0));

    // Warp to when proposal is ready (T + 1 day)
    vm.warp(block.timestamp + MINIMUM_DELAY);
    assertTrue(timelock.isOperationReady(id), "should be ready under 30-day");

    // Wait 2 more days — still within 30-day window but exceeds new 1-day
    vm.warp(block.timestamp + 2 days);
    assertTrue(timelock.isOperationReady(id), "still ready under old 30-day");

    // Execution reverts: _afterCall checks with NEW 1-day expiration
    // (T+1day) + 1day = T+2days <= T+3days => fails
    vm.expectRevert("Timelock: operation is not ready");
    timelock.execute(address(timelock), 0, payload, bytes32(0));

    // Proposal is stuck — still live, still "ready" under old window, but unexecutable
    assertEq(timelock.getAllProposals().length, 1, "proposal still live");
    assertTrue(timelock.isOperationReady(id), "still ready under 30-day");
}
```

## [Medium] `initialize()` has no access control — front-running DoS or malicious calldata injection when using TimelockFactory directly
> **KLD-016** · Normalized: Low

- File: src/Timelock.sol:316-329, src/TimelockFactory.sol:37-55
- Severity: Medium
- Confidence: Medium
- Description: `Timelock.initialize()` has no access control — anyone can call it. `TimelockFactory.createTimelock()` deploys the Timelock but **never calls `initialize()`**, despite `DeploymentParams` containing calldata-check fields (`contractAddresses`, `selectors`, `startIndexes`, `endIndexes`, `datas`) that are silently ignored by the constructor. The `InstanceDeployer` calls both `createTimelock()` and `initialize()` atomically in the same transaction, but `TimelockFactory.createTimelock()` is a public function with no access restriction. If anyone uses the factory directly, an attacker can front-run the `initialize()` call to either DoS the timelock (set `initialized = true` with empty arrays) or inject malicious calldata checks that allow hot signers to drain funds.
- Attack scenario:
  **DoS variant:**
  1. Victim calls `TimelockFactory.createTimelock(safe, params)` directly (not via InstanceDeployer).
  2. Attacker monitors the mempool and front-runs the victim's subsequent `initialize()` call with empty arrays.
  3. `initialized` is set to `true`; no calldata checks are added.
  4. Victim's `initialize()` reverts with "already initialized".
  5. Hot signers cannot execute whitelisted calls (`checkCalldata` reverts with "No calldata checks found"). The Safe must schedule a timelock proposal (≥1 day delay) to add calldata checks via `addCalldataChecks`.

  **Malicious injection variant:**
  1. Same setup. Attacker front-runs `initialize()` with calldata checks for an attacker-controlled contract with a wildcard check (startIndex == endIndex == 4).
  2. Any hot signer who calls `executeWhitelisted` on that contract executes arbitrary attacker-specified calldata, potentially draining timelock funds.
- PoC:
```solidity
function testInitializeFrontRunDoS() public {
    DeploymentParams memory params = DeploymentParams({
        minDelay: MINIMUM_DELAY,
        expirationPeriod: 7 days,
        pauser: guardian,
        pauseDuration: PAUSE_DURATION,
        hotSigners: hotSigners,
        contractAddresses: new address[](0),
        selectors: new bytes4[](0),
        startIndexes: new uint16[](0),
        endIndexes: new uint16[](0),
        datas: new bytes[][](0),
        salt: bytes32(0)
    });

    // Deploy timelock via factory directly (initialize NOT called by factory)
    address newTimelock = timelockFactory.createTimelock(address(safe), params);
    assertFalse(Timelock(newTimelock).initialized(), "should not be initialized");

    // Attacker front-runs initialize with empty arrays
    vm.prank(address(0xdeadbeef));
    Timelock(newTimelock).initialize(
        new address[](0), new bytes4[](0),
        new uint16[](0), new uint16[](0), new bytes[][](0)
    );
    assertTrue(Timelock(newTimelock).initialized(), "attacker initialized it");

    // Victim's initialize reverts
    vm.expectRevert("Timelock: already initialized");
    Timelock(newTimelock).initialize(
        new address[](0), new bytes4[](0),
        new uint16[](0), new uint16[](0), new bytes[][](0)
    );

    // Hot signers cannot execute any whitelisted calls
    vm.prank(hotSigners[0]);
    vm.expectRevert("CalldataList: No calldata checks found");
    Timelock(newTimelock).executeWhitelisted(address(0), 0, "");
}
```

## Coverage

- src/ConfigurablePause.sol
- src/Timelock.sol
- src/TimelockFactory.sol
- src/Guard.sol
- src/views/AddressCalculation.sol
- src/utils/Create2Helper.sol
- src/utils/Constants.sol
- src/InstanceDeployer.sol
- src/RecoverySpell.sol
- src/RecoverySpellFactory.sol
- src/deploy/SystemDeploy.s.sol
- src/BytesHelper.sol
- src/interface/WETH9.sol
- src/interface/IMulticall3.sol
- src/interface/IMorpho.sol
- src/interface/CEtherInterface.sol
- src/interface/CErc20Interface.sol

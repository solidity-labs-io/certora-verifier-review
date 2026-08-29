## [MEDIUM] Off-by-one in _addCalldataCheck overlap validation rejects valid adjacent non-overlapping ranges
> **KLD-007** · Normalized: Medium

- File: src/Timelock.sol:L1119-L1123
- Severity: Medium
- Confidence: High
- Description: The overlap check in `_addCalldataCheck` uses strict inequalities (`startIndex > indexes[i].endIndex || endIndex < indexes[i].startIndex`). Because byte ranges are `[startIndex, endIndex)` (end-exclusive), adjacent ranges like `[16, 36)` and `[36, 68)` cover disjoint byte sets (bytes 16-35 and bytes 36-67 respectively). The strict `>` rejects them since `36 > 36` is false. This prevents administrators from independently whitelisting adjacent ABI-encoded parameters on the same function selector. The check should use `>=` and `<=` instead.
- Attack scenario:
  1. Admin whitelists a DeFi protocol function `deposit(address recipient, uint256 amount)` on the timelock
  2. Admin adds calldata check `[16, 36)` to verify `recipient` is the timelock address — succeeds
  3. Admin attempts to add calldata check `[36, 68)` to restrict `amount` to approved values — reverts with "Partial check overlap" despite the ranges being disjoint
  4. Unable to check both adjacent parameters independently, the admin must either leave `amount` entirely unchecked (hot signer can supply any value), combine ranges into `[16, 68)` requiring enumeration of every valid (address, amount) pair, or use a gap workaround `[37, 68)` that leaves byte 36 (most significant byte of `amount`) unchecked — allowing a hot signer to set that byte to any value, drastically altering the interpreted amount
- PoC:
```solidity
function testAdjacentNonOverlappingCalldataChecksRejected() public {
    MockLending lending = new MockLending();

    // Add first check for recipient address at bytes [16, 36)
    bytes[] memory data1 = new bytes[](1);
    data1[0] = abi.encodePacked(address(timelock));
    vm.prank(address(timelock));
    timelock.addCalldataCheck(
        address(lending), MockLending.deposit.selector, 16, 36, data1
    );

    // Attempt to add adjacent check for amount at bytes [36, 68)
    // [16,36) covers bytes 16-35; [36,68) covers bytes 36-67. No overlap.
    bytes[] memory data2 = new bytes[](1);
    data2[0] = abi.encode(uint256(1000));
    vm.prank(address(timelock));
    vm.expectRevert("CalldataList: Partial check overlap");
    timelock.addCalldataCheck(
        address(lending), MockLending.deposit.selector, 36, 68, data2
    );
    // Reverts even though [16, 36) and [36, 68) are disjoint byte ranges
}
```

## [MEDIUM] RecoverySpellFactory transient storage not cleared between calls causes false duplicate detection
> **KLD-015** · Normalized: Low

- File: src/RecoverySpellFactory.sol:L59-L71
- Severity: Medium
- Confidence: High
- Description: `createRecoverySpell` uses transient storage (`tstore`/`tload`) to detect duplicate owners within a single call, but never clears those slots afterward. Per EIP-1153, transient storage persists for the entire transaction. If `createRecoverySpell` is invoked multiple times within one transaction (e.g., via a multicall or batch deployer) and any owner address appears in more than one call, subsequent calls revert with "Duplicate owner" even though each individual owner array contains no duplicates.
- Attack scenario:
  1. A governance contract or multicall batches two `createRecoverySpell` calls in one transaction to efficiently set up multiple recovery paths
  2. First call creates a recovery spell with owners `[Alice, Bob]` — succeeds, writing `tstore(Alice, 1)` and `tstore(Bob, 1)`
  3. Second call creates a recovery spell with owners `[Alice, Carol]` — `tload(Alice)` returns 1 from the first call's stale transient storage
  4. Second call reverts with "Duplicate owner" despite `[Alice, Carol]` having no duplicates
  5. The entire batch fails; the deployer must split into separate transactions
- PoC:
```solidity
function testTransientStorageLeakBlocksBatchCreation() public {
    address[] memory owners1 = new address[](2);
    owners1[0] = address(0xA);
    owners1[1] = address(0xB);

    address[] memory owners2 = new address[](2);
    owners2[0] = address(0xA); // Also in owners1
    owners2[1] = address(0xC);

    // First creation succeeds
    factory.createRecoverySpell(
        bytes32(uint256(1)), owners1, address(safe), 1, 1, 1 days
    );

    // Second creation in the same transaction reverts — stale tstore(0xA, 1)
    vm.expectRevert("RecoverySpell: Duplicate owner");
    factory.createRecoverySpell(
        bytes32(uint256(2)), owners2, address(safe), 1, 1, 1 days
    );
}
```

## [MEDIUM] RecoverySpellFactory allows SENTINEL address as owner, creating permanently non-functional recovery spells
> **KLD-008** · Normalized: Medium

- File: src/RecoverySpellFactory.sol:L135-L137
- Severity: Medium
- Confidence: Medium
- Description: The `_paramChecks` function validates that no owner is `address(0)` but does not check for `address(1)` — the SENTINEL_OWNERS constant used by Gnosis Safe's internal linked list. A RecoverySpell created with `address(1)` as an owner deploys successfully, but `executeRecovery` will always revert because the Safe's `OwnerManager` rejects SENTINEL as an owner with error "GS203". This permanently bricks that recovery spell with no way to fix it.
- Attack scenario:
  1. An admin creates a RecoverySpell via the factory with owners `[address(0xA), address(0x1)]`
  2. The factory's `_paramChecks` passes — `address(0x1) != address(0)` is true
  3. The RecoverySpell deploys and is added as a module to the Safe
  4. When recovery is attempted, `executeRecovery` builds a multicall that includes `addOwnerWithThreshold(address(0x1), 1)`
  5. The Safe's `OwnerManager` rejects `address(0x1)` with "GS203", reverting the entire multicall
  6. The recovery spell is permanently non-functional; if it is the only recovery path and the safe signers lose their keys, funds are locked
- PoC:
```solidity
function testSentinelOwnerBricksRecovery() public {
    address[] memory owners = new address[](2);
    owners[0] = address(0xA);
    owners[1] = address(0x1); // SENTINEL_OWNERS

    // Factory allows it — no validation against address(1)
    RecoverySpell spell = factory.createRecoverySpell(
        bytes32(0), owners, address(safe), 1, 1, 1 days
    );
    // Deploys without error
    assertTrue(address(spell) != address(0));

    // Later, executeRecovery always fails:
    // The multicall includes addOwnerWithThreshold(address(1), 1)
    // which the Safe rejects with "GS203"
    // vm.expectRevert(); spell.executeRecovery(prevModule, v, r, s);
}
```

## [MEDIUM] Timelock initialize function lacks access control allowing front-running on directly-deployed timelocks
> **KLD-016** · Normalized: Low

- File: src/Timelock.sol:L316-L329
- Severity: Medium
- Confidence: Low
- Description: The `initialize` function can be called by any address — it is only guarded by `require(!initialized)`. While the `InstanceDeployer` flow calls `initialize` atomically in the same transaction as timelock creation (preventing front-running), a Timelock deployed directly through `TimelockFactory` exposes a window between deployment and initialization. An attacker can front-run the legitimate `initialize` call and set calldata checks that whitelist calls routing funds through DeFi protocols to attacker-controlled addresses. The contract's "DO NOT DEPLOY OUTSIDE OF INSTANCE DEPLOYER" comment is the only protection, with no technical enforcement.
- Attack scenario:
  1. A user deploys a Timelock directly through `TimelockFactory.createTimelock()`
  2. The user submits a separate transaction to call `initialize()` with legitimate calldata checks
  3. An attacker front-runs by calling `initialize()` first, whitelisting `ERC20.transfer(attacker_address, ...)` on a token contract
  4. The user's `initialize()` reverts with "already initialized"
  5. Hot signers, trusting the system configuration, execute whitelisted calls that route tokens to the attacker's address
- PoC:
```solidity
function testAnyoneCanFrontRunInitialize() public {
    // Deploy timelock directly via factory (not InstanceDeployer)
    address timelockAddr = TimelockFactory(factory).createTimelock(
        address(safe), params
    );
    Timelock tl = Timelock(payable(timelockAddr));

    // Attacker front-runs initialize with malicious calldata checks
    address[] memory targets = new address[](1);
    targets[0] = address(someToken); // Not timelock or safe — passes validation
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(keccak256("transfer(address,uint256)"));
    uint16[] memory starts = new uint16[](1);
    starts[0] = 16;
    uint16[] memory ends = new uint16[](1);
    ends[0] = 36;
    bytes[][] memory datas = new bytes[][](1);
    datas[0] = new bytes[](1);
    datas[0][0] = abi.encodePacked(address(attacker));

    vm.prank(attacker);
    tl.initialize(targets, selectors, starts, ends, datas);

    // Legitimate initialize call fails
    vm.expectRevert("Timelock: already initialized");
    tl.initialize(/* legitimate params */);
}
```

## [MEDIUM] RecoverySpellFactory allows zero recoveryThreshold enabling unauthorized recovery execution
> **KLD-009** · Normalized: Medium

- File: src/RecoverySpellFactory.sol:L118-L138
- Severity: Medium
- Confidence: High
- Description: The `_paramChecks` function validates `threshold != 0` but omits the equivalent check for `recoveryThreshold`. A recovery spell created with `recoveryThreshold = 0` allows `executeRecovery` to be called by any address with zero signatures after the delay period. The signature requirement check `recoveryThreshold <= v.length` passes with `0 <= 0`, the signature verification loop executes zero iterations, and the function proceeds to rotate all Safe owners without any authorization. This is an asymmetric validation gap — `threshold` is protected but `recoveryThreshold` is not.
- Attack scenario:
  1. A deployment script or frontend passes `recoveryThreshold = 0` due to a configuration error
  2. The recovery spell is deployed and added as a module to the Safe via `createSystemInstance`
  3. After the delay period, any address calls `executeRecovery(previousModule, [], [], [])` with empty signature arrays
  4. `recoveryThreshold <= v.length` passes (0 <= 0), the signature loop is skipped
  5. All Safe owners are rotated to the recovery spell's owners without any signature authorization
  6. The attacker gains control of the Safe and all its assets
- PoC:
```solidity
function testZeroRecoveryThresholdAllowsUnauthorizedRecovery() public {
    address[] memory owners = new address[](2);
    owners[0] = address(0xA);
    owners[1] = address(0xB);

    // threshold=0 correctly reverts
    vm.expectRevert("RecoverySpell: Threshold must be gt 0");
    factory.createRecoverySpell(
        bytes32(uint256(1)), owners, address(safe), 0, 1, 1 days
    );

    // recoveryThreshold=0 does NOT revert — asymmetric validation gap
    RecoverySpell spell = factory.createRecoverySpell(
        bytes32(uint256(2)), owners, address(safe), 1, 0, 1 days
    );
    assertTrue(address(spell) != address(0));
    assertEq(spell.recoveryThreshold(), 0);

    // After delay, anyone calls executeRecovery with ZERO signatures
    vm.warp(block.timestamp + 1 days + 1);
    uint8[] memory v = new uint8[](0);
    bytes32[] memory r = new bytes32[](0);
    bytes32[] memory s = new bytes32[](0);

    // Passes all signature checks, only fails at execTransactionFromModule
    // because mock doesn't implement it
    vm.expectRevert();
    spell.executeRecovery(address(0x1), v, r, s);
}
```

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
- src/deploy/SystemDeploy.s.sol — reviewed
- src/interface/CErc20Interface.sol — reviewed
- src/interface/CEtherInterface.sol — reviewed
- src/interface/IMorpho.sol — reviewed
- src/interface/IMulticall3.sol — reviewed
- src/interface/WETH9.sol — reviewed

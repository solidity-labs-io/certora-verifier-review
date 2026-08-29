## [MEDIUM] Recovery delay can elapse before the module is enabled
> **KLD-012** · Normalized: Medium
- File: src/RecoverySpell.sol:L118-L126
- Severity: Medium
- Confidence: High
- Description: `recoveryInitiated` is set when the permissionless factory deploys the spell, even if the spell is not yet an enabled Safe module. A counterfactually predeployed spell can therefore be fully aged when `InstanceDeployer` later enables it, eliminating the delay during which the original Safe owners are supposed to remove a malicious recovery spell.
- Attack scenario: A compromised recovery quorum copies the deterministic Safe and recovery configuration from an existing chain, permissionlessly deploys the same Safe proxy and recovery spell on an undeployed chain, and waits out `delay`. When the honest hot signer later calls `createSystemInstance`, it adopts the predeployed Safe and enables the already-mature spell; the quorum immediately executes recovery, becomes the Safe owner set, and can govern the Timelock without giving the original owners the configured cancellation window.
- PoC: In a Foundry test, calculate the target Safe, call `SafeProxyFactory.createProxyWithNonce` with the initializer and `creationSalt` used by `InstanceDeployer`, then call `recoveryFactory.createRecoverySpell(salt, recoveryOwners, safe, threshold, recoveryThreshold, delay)` and sign `spell.getDigest()` with `recoveryThreshold` keys. After `vm.warp(block.timestamp + delay + 1)`, prank the legitimate hot signer and call `deployer.createSystemInstance(instance)` with `address(spell)` in `recoverySpells`; without another warp, call `spell.executeRecovery(address(1), v, r, s)` and assert that `safe.getOwners()` has already rotated to `recoveryOwners`.

## [MEDIUM] Unbounded expiration period can permanently brick timelocked execution
> **KLD-006** · Normalized: Medium
- File: src/Timelock.sol:L289-L294
- Severity: Medium
- Confidence: High
- Description: The constructor and `updateExpirationPeriod` enforce only a lower bound, while readiness and expiry add `expirationPeriod` to an operation timestamp using checked arithmetic. An expiration period near `type(uint256).max` makes every proposal readiness check revert, including a proposal intended to restore a safe value, permanently disabling non-whitelisted governance.
- Attack scenario: An instance is deployed with `expirationPeriod = type(uint256).max` and later receives assets. The Safe can still schedule operations, but every `execute` and `executeBatch` reverts while evaluating `timestamp + expirationPeriod`; because changing the period itself requires a successfully executed self-call, assets that cannot be recovered through an existing hot-signer whitelist remain stranded.
- PoC: In a Foundry test, first `vm.warp(31 days)`, deploy `new Timelock(address(this), 1 days, type(uint256).max, guardian, 1 days, new address[](0))`, and call `schedule(address(timelock), 0, abi.encodeCall(timelock.updateExpirationPeriod, (1 days)), bytes32(0), 1 days)`. Warp to the stored proposal timestamp, then expect `stdError.arithmeticError` when calling `execute` with the same arguments; scheduling the same repair with a fresh salt also cannot make it executable.

## [MEDIUM] Factory accepts recovery owners that Safe can never install
> **KLD-008** · Normalized: Medium
- File: src/RecoverySpellFactory.sol:L124-L137
- Severity: Medium
- Confidence: High
- Description: The factory rejects only the zero address, but Safe also rejects its sentinel `address(1)` and the Safe itself as owners. A spell containing either address deploys successfully and can be enabled as a module, yet every recovery attempt deterministically fails during `swapOwner` or `addOwnerWithThreshold`.
- Attack scenario: A user configures and installs a factory-created spell whose recovery owner list contains `address(1)`, then later loses the original Safe keys. Even with the required recovery signatures and elapsed delay, Safe rejects the replacement owner, the module transaction rolls back, and the only configured recovery path cannot unlock the wallet.
- PoC: In a Foundry test, calculate the system Safe with no spells, set `recoveryOwners = [address(1)]`, calculate its spell address, add that address to `instance.recoverySpells`, and deploy the instance normally. Call `createRecoverySpell(salt, recoveryOwners, safe, 1, 0, 0)`, `vm.warp(block.timestamp + 1)`, then expect `"RecoverySpell: Recovery failed"` from `spell.executeRecovery(address(1), new uint8[](0), new bytes32[](0), new bytes32[](0))`; assert the original Safe owners are unchanged.

## [MEDIUM] Failed Safe module calls are recorded as executed
> **KLD-014** · Normalized: Medium
- File: src/Timelock.sol:L1021-L1025
- Severity: Medium
- Confidence: High
- Description: `_execute` checks only whether the outer call reverted and discards return data, but Safe's `execTransactionFromModule` returns `false` rather than reverting when its inner transaction fails. The Timelock consequently emits `CallExecuted`, removes the proposal, and marks it done even though a critical Safe owner, guard, or module change did not occur.
- Attack scenario: Owners queue one proposal to disable a newly activated, compromised recovery spell using its current linked-list predecessor and another to enable its replacement. Once both are ready, the compromised quorum executes the enable first, changing the old spell's predecessor, then executes the stale disable; Safe returns `false`, but the Timelock records success. If the old spell's recovery delay is less than two Timelock delays, it becomes executable before a corrected disable can mature and takes over the Safe.
- PoC: In a Foundry integration test with module order `sentinel -> oldSpell -> timelock` and `oldSpell.delay() = timelock.minDelay() + 1`, schedule two calls targeting the Safe's `execTransactionFromModule`: one enabling `newSpell`, and one calling `disableModule(address(1), oldSpell)`. After both mature, execute the enable first and the disable second; assert the latter does not revert, `isOperationDone(disableId)` and `isModuleEnabled(oldSpell)` are both true, and Safe emitted `ExecutionFromModuleFailure`; warp two seconds and execute `oldSpell` before any freshly scheduled disable can mature.

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

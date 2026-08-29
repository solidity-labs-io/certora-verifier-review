## [MEDIUM] Hot signer can permanently stash the entire native balance in cETH (wildcard `mint` + unchecked `value`) with no whitelisted exit
> **KLD-010** · Normalized: Medium
- File: src/Timelock.sol:488-493 (wildcard), src/Timelock.sol:715-755 (value unchecked); reference whitelist: test/integration/System.t.sol:283-292 (cEther.mint wildcard [4,4), weth.deposit/withdraw wildcards)
- Severity: Medium
- Confidence: High
- Description: `executeWhitelisted` performs no check on `value`, and an `Index` with `startIndex==endIndex` acts as a wildcard. The reference config whitelists `CEtherInterface.mint()` as a [4,4) wildcard and `WETH9.deposit()` as a wildcard, meaning a hot signer can call `executeWhitelisted(cEther, address(this).balance, mintSelector)` and convert the ENTIRE native balance into cETH instantaneously (or `weth.deposit` then `weth.withdraw` for a WETH loop). There is no whitelisted entry for `redeem`/`redeemUnderlying`, so the funds are locked in the cToken and can only be extracted via a delayed governance proposal — violating the project's own documented requirement ("do not allow unwrapping" EDGECASES.md:9-11) and turning a compromised hot key into a liquidity freeze of all native funds with no same-tx escape.
- Attack scenario:
  1. Hot signer (compromised or rogue): `executeWhitelisted(cEtherProxy, address(this).balance, abi.encodeCall(CEtherInterface.mint,()))` — wildcard [4,4) matches, `value` unrestricted — entire ETH balance now cETH.
  2. `executeWhitelisted(cEtherProxy, 0, abi.encodeCall(CEtherInterface.redeemUnderlying, (amount)))` reverts with "CalldataList: No calldata checks found" (no redeem entry configured).
  3. All ETH is inaccessible to hot signers (goal achieved — DoS/freeze) and can only be recovered by scheduling `redeem` through the Safe (timelocked, minDelay up to 30 days), during which all DeFi positions remain unserviced.
- PoC: Foundry test outline:
  ```solidity
  vm.deal(address(timelock), 100 ether);
  vm.prank(HOT_SIGNER_ONE);
  timelock.executeWhitelisted(cEther, 100 ether, abi.encodeWithSignature("mint()"));
  assertEq(address(timelock).balance, 0);
  vm.expectRevert("CalldataList: No calldata checks found");
  timelock.executeWhitelisted(cEther, 0, abi.encodeWithSignature("redeemUnderlying(uint256)", 100 ether));
  ```

## [MEDIUM] `createSystemInstance` silently deploys a 1-of-1 wallet when `owners.length == 1`; requested `threshold` is never validated for single-owner instances
> **KLD-017** · Normalized: Low
- File: src/InstanceDeployer.sol:315-328 (threshold branch), lack of validation at src/InstanceDeployer.sol:139-163
- Severity: Medium
- Confidence: High
- Description: When `instance.owners.length == 1`, the final `addOwnerWithThreshold(_, instance.threshold)` is skipped entirely, and `swapOwner` does not set a threshold, so the Safe ends at threshold 1 no matter what was requested (e.g. `threshold = 2` with 1 owner, or `threshold = 0`). For multiple owners, `threshold = 0` reverts via Safe's error GS202 (`changeThreshold(0)` requires `_threshold >= 1`) — the same misconfiguration either silently deploys a wallet with a single-signer quorum or hard-reverts, with no upfront validation in `createSystemInstance` (it also accepts a zero-address pauser, permanently disabling the pause capability).
- Attack scenario: 1. Frontend/script passes `owners=[0xA]`, `threshold=2` (e.g. operator intends a leader 2-of-2 and mis-types owner list). 2. `createSystemInstance` succeeds, emitting `SystemInstanceCreated`; `safe.getThreshold() == 1` — a quorum-1 wallet is deployed with no error. 3. When a single key of A is lost/compromised, all funds are under the attacker's control; the expected 2-of-1 protection is silently discarded; recovery spells/guardian were configured for this same (now weaker) wallet. There is no post-deployment detection unless the UI separately loads `safe.getThreshold()`.
- PoC: Foundry outline:
  ```solidity
  NewInstance memory i = defaultInstance();
  i.owners = new address[](1); i.owners[0] = alice;
  i.threshold = 2; // invalid > owners.length
  deployer.createSystemInstance(i); // succeeds — no revert
  assertEq(safe.getOwners().length, 1);
  assertEq(safe.getThreshold(), 1, "requested 2-of-1 silently deployed as 1-of-1");
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
- src/views/AddressCalculation.sol
- src/utils/Create2Helper.sol
- src/utils/Constants.sol
- src/deploy/SystemDeploy.s.sol
- src/interface/CErc20Interface.sol
- src/interface/CEtherInterface.sol
- src/interface/IMulticall3.sol
- src/interface/WETH9.sol

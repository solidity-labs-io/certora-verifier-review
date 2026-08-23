## [HIGH] Whitelist does not pin Morpho markets for `supplyCollateral`/`borrow`, letting a compromised hot signer drain the wallet via an attacker-created market and liquidation
- File: src/Timelock.sol:475-504 (checkCalldata), src/Timelock.sol:715-755 (executeWhitelisted/executeWhitelistedBatch); exposed by the reference whitelist configuration in test/integration/System.t.sol:280-295
- Severity: High
- Confidence: Medium
- Description: `checkCalldata` verifies only the byte ranges declared by the configured `Index` entries, and the reference configuration pins `MarketParams` (market id) only for `supply` ([4,164), System.t.sol:292-298). For `supplyCollateral` only `onBehalf` ([208,228) — arg3 word6, last 20 bytes) is checked, and for `borrow` only `receiver` ([272,292) — arg5 word8, last 20 bytes). `MarketParams` is unconstrained for `supplyCollateral` and `borrow`. A hot signer can therefore park the timelock's tokens as collateral into ANY Morpho market — including a market the attacker creates (`createMarket` is permissionless; attacker supplies the oracle, loan token and liquidity) — and borrow max against it, then anyone (the attacker) liquidates the position, seizing the collateral to themselves. `liquidate` is permissionless and not whitelist-gated.
- Attack scenario:
  1. Attacker (or compromised hot signer) deploys a `FAKE` ERC20 and an oracle `O` it fully controls; calls `morpho.createMarket(MarketParams(loanToken=FAKE, collateralToken=weth, oracle=O, irm=0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC, lltv=915000000000000000))` (the fixture's enabled IRM and a governance-enabled LTV) and seeds FAKE liquidity directly via `morpho.supply(scamMarket, max, 0, attacker, "")` — required because `borrow` reverts with INSUFFICIENT_LIQUIDITY unless market supply exceeds the requested borrow.
  2. Hot signer: `executeWhitelistedBatch([approve(weth, morpho, max)], [supplyCollateral(scamMarket, balance, timelock, "")])` — the whitelist checks only the last 20 bytes of `onBehalf` ([208,228) = timelock) and the approve spender ([16,36) = morpho); MarketParams is unconstrained — the timelock's entire WETH is posted into the attacker's market.
  3. Hot signer: `executeWhitelisted(morpho, 0, borrow(scamMarket, 0, maxShares, timelock, timelock))` — only `receiver` ([272,292) = timelock) is checked; MarketParams/onBehalf/amounts unconstrained — borrows the max against the collateral while oracle `O` reports a favorable price.
  4. Attacker reprices via `O` (collateral worth ≈ 0 in the market's terms) and calls `morpho.liquidate(scamMarket, timelock, exactCollateral, 0, "")` directly — liquidation is permissionless and not whitelisted; the seized WETH goes to `msg.sender` (attacker) and the FAKE debt is absorbed as bad debt against the attacker's own liquidity. Full loss of the collateral; repeatable for every asset the whitelist lets the wallet hold (DAI/eUSD via `withdraw`/`withdrawCollateral`+receiver, ETH via the WETH wrap wildcards), so the entire balance can be drained.
- PoC (Foundry outline):
  ```solidity
  // attacker: FAKE (mintable ERC20) + oracle O (attacker-set price()); irM = fixture 0x870aC11D48b15Db9a138Cf899d20F13F79Ba00BC; lltv = 0.915e18
  morpho.createMarket(MarketParams(FAKE, weth, O, IRM, 0.915e18));
  morpho.supply(scamMarket, type(uint256).max, 0, attacker, ""); // liquidity: borrow requires totalSupplyAssets
  deal(address(weth), address(timelock), 100 ether);
  vm.prank(HOT_SIGNER);
  timelock.executeWhitelistedBatch(
      [weth, morpho], [0, 0],
      [abi.encodeCall(IERC20.approve, (morpho, type(uint256).max)),
       abi.encodeCall(IMorphoBase.supplyCollateral, (scamMarket, 100 ether, address(timelock), ""))]);
  vm.prank(HOT_SIGNER);
  timelock.executeWhitelisted(morpho, 0, abi.encodeCall(IMorphoBase.borrow, (scamMarket, 0, type(uint256).max, address(timelock), address(timelock))));
  o.setPrice(1); // collateral ≈ worthless → unhealthy
  morpho.liquidate(scamMarket, address(timelock), 100 ether, 0, ""); // seize all collateral to attacker
  assertLt(weth.balanceOf(address(timelock)), 100 ether); // collateral gone
  ```
  Mitigation: add the market-params check [4,164) to the `supplyCollateral`, `borrow`, `withdraw` and `withdrawCollateral` whitelist entries (like the `supply` entry), i.e. only allow the predefined markets.

## [MEDIUM] Hot signer can permanently stash the entire native balance in cETH (wildcard `mint` + unchecked `value`) with no whitelisted exit
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
- src/interface/IMorpho.sol
- src/interface/CErc20Interface.sol
- src/interface/CEtherInterface.sol
- src/interface/IMulticall3.sol
- src/interface/WETH9.sol
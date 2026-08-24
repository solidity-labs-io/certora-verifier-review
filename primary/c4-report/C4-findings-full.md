# Code4rena Audit Competition — October 2024 Kleidi (full findings)

**Local copy of the contest outcome.** The upstream repo stub (`audit/Code4rena.md` at `1290079`) links to the C4 site; the substantive findings below are from https://code4rena.com/reports/2024-10-kleidi (published 2024-11-20, judged by Alex the Entreprenerd, 27 wardens, contest window Oct 15–25 2024).

## Outcome

**0 High / 0 Critical. 3 Medium.** 11 low/non-critical reports.

## M-01 — Gas griefing/attack via creating the proposals (Medium)
*Submitted by Allarious; 10 duplicates.*
`Timelock.sol` schedule/cancel/pause. Once proposals are submitted they must be cancelled or executed. With ≥threshold compromised keys, attackers spam `schedule` with distinct salts; defenders must pay gas to `pause()` (iterates all live proposals) or `cancel()` one-by-one, and cannot use funds inside the wallet for gas. Judge: attack is multi-block and costlier than defense (7–22×), Medium appropriate. Mitigation adopted upstream: epochs invalidating proposals at pause.

## M-02 — Wrong handling of call data check indices, forcing reverts (Medium)
*Submitted by 0xAlix2; 9 duplicates.*
`BytesHelper.sliceBytes` computes `length = end - start` and `_addCalldataCheck` requires `data[i].length == endIndex - startIndex` — both missing `+1` for inclusive indices. Parameters filling all 32 bytes (e.g. `type(uint256).max` approval) force whitelisted calls to revert (`End index is greater than the length of the byte string`). Sponsor confirmed; fixed in PR #54 after an earlier partial fix was backed out.

## M-03 — `updateExpirationPeriod()` cannot execute when lowering the period (Medium)
*Submitted by dhank; 1 duplicate.*
`_afterCall` re-checks `isOperationReady(id)` using the *newly set* `expirationPeriod`. Executing a proposal that lowers the period reverts with "Timelock: operation is not ready" if execution happens after the new (shorter) expiry would have passed. Judge initially Low/QA, raised to Medium. Recommended fix: drop the readiness re-check in `_afterCall`.

## Judged low/QA highlights (from top low report + judge rulings)

- **Low** NatSpec claims `revokeHotSigner` callable by timelock; modifier is `onlySafe` (inconsistency).
- **Low** Updating `expirationPeriod` to a smaller value instantly expires live proposals.
- **Refactor** "arity mismatch" typo; duplicated code in `_addCalldataCheck`.
- 11 total low/QA reports; no High/Critical findings.

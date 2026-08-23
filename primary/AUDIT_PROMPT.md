# Audit Task

You are a senior smart contract security auditor. Perform a security audit of the Solidity codebase in your current working directory (a Foundry repo).

## Scope

- Audit only `src/` (~1,400 LOC). You may read `test/`, `certora/`, `docs/`, and `lib/` for context, but findings must be in `src/`.
- Do not modify any files. Read-only audit.
- Do not search the internet for this repo or its code. Judge only the code in front of you.
- There is no version control available in this directory: no `.git`, no branches, no history, and you cannot check out anything else. Work with the files as they are.

## Deliverable

Write your findings to `FINDINGS.md` in the repo root using exactly this format, one block per finding, ordered by severity:

```
## [SEVERITY] Short title
- File: path/to/File.sol:L123-L145
- Severity: High | Medium
- Confidence: High | Medium | Low
- Description: what is wrong (1-3 sentences)
- Attack scenario: concrete step-by-step exploitation or failure mode
- PoC: Foundry test or exact calldata/call sequence demonstrating the issue (do not add files)
```

Rules:
- Only report Medium- or High-severity issues. No Low, Info, gas, or style findings.
- Every finding MUST include a concrete PoC — a Foundry test outline or exact call sequence. A finding without a PoC will be discarded.
- Be as succinct as possible. No preamble, no summaries, no restating code.
- Report only real issues. Quality over quantity.
- Include edge cases: off-by-one errors, boundary values (zero, max), reentrancy, role confusion, state transitions.
- End the file with a one-line-per-file `## Coverage` section listing every `src/` file you reviewed.

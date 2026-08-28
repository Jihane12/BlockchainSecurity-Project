# VulnerableVault — Security Audit (ESTIAM Final Project)

Blockchain Security (4BLOCKC / E4CCSN) — audit of a staking vault contract,
with a Hardhat test suite that **proves each vulnerability before the fix**
and **proves the fix holds after**.

## Project structure

```
contracts/
  VulnerableVault.sol        # original, vulnerable contract (audit target)
  VulnerableVaultFixed.sol   # corrected contract
  MockRewardToken.sol        # minimal reward token, needed for the constructor
  ReentrancyAttacker.sol     # attacker contract used to demonstrate Finding H3
test/
  VulnerableVault.test.js       # exploits run against the BEFORE contract
  VulnerableVaultFixed.test.js  # same scenarios run against the AFTER contract
hardhat.config.js
package.json
```

## Prerequisites

- [Node.js](https://nodejs.org) ≥ 18
- npm (comes with Node.js)

## Setup

```bash
git clone <this-repo-url>
cd vault-audit-project
npm install

```

<img width="2338" height="1700" alt="image" src="https://github.com/user-attachments/assets/2bb98364-2e3b-432b-b88f-50c567545b60" />

## Compile

```bash
npx hardhat compile
```

## Run the tests

```bash
# everything (before + after)
npx hardhat testz

# only the exploits against the vulnerable contract
npm run test:before

# only the checks against the fixed contract
npm run test:after
```

Expected result: **7 passing tests** — 3 proving the vulnerabilities exist in
`VulnerableVault`, 4 proving they are closed in `VulnerableVaultFixed`.

```
VulnerableVault (BEFORE fix)
  ✔ [Finding H3] reentrancy: attacker drains far more ETH than it deposited
  ✔ [Finding H2] anyone can change the owner (missing access control)
  ✔ [Finding H1] anyone can drain all ETH via emergencyWithdraw (missing access control)

VulnerableVaultFixed (AFTER fix)
  ✔ [Finding H3 fixed] reentrancy attempt reverts the whole transaction
  ✔ [Finding H2 fixed] setOwner reverts when called by a non-owner
  ✔ [Finding H1 fixed] emergencyWithdraw reverts when called by a non-owner
  ✔ [Finding H2] the legitimate owner can still change ownership
```

## Findings summary

| ID | Severity | Finding | Fix |
|----|----------|---------|-----|
| H1 | High | `emergencyWithdraw` has no access control — anyone can drain all ETH | Added `onlyOwner` |
| H2 | High | `setOwner` has no access control — anyone can take ownership | Added `onlyOwner` |
| H3 | High | `withdraw` sends ETH before updating balances → reentrancy | Checks-effects-interactions + `noReentrant` guard |
| H4 | High | `onlyOwner` modifier used `tx.origin` instead of `msg.sender` | Switched to `msg.sender` |
| M1 | Medium | `pickWinner` uses `blockhash`/`timestamp` as randomness — predictable/manipulable | Flagged; recommend Chainlink VRF for production |
| M2 | Medium | `stakers` array allows duplicate/stale entries (deposit multiple times, withdraw to 0 but stay listed) — skews reward odds | Deduplicated, active-stakers-only list with swap-and-pop removal |
| M3 | Medium | Return value of `rewardToken.transfer()` ignored — silent failures reported as success | Return value checked; failure emits `RewardTransferFailed` instead of `RewardPaid` |
| L1 | Low | No zero-address checks on constructor / `setOwner` / `emergencyWithdraw` | `require(... != address(0))` added |

Full technical write-up (impact, PoC references, recommendations) belongs in
the separate audit report submitted alongside this repository.

## Push this project to GitHub

```bash
cd vault-audit-project
git init
git add .
git commit -m "Initial commit: VulnerableVault audit + before/after tests"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

`node_modules/`, `cache/`, and `artifacts/` are already excluded via
`.gitignore` — anyone cloning the repo just needs to run `npm install`.

## Disclaimer

`VulnerableVault.sol` is intentionally insecure. Never deploy it, or funds
based on it, to mainnet or with real value.

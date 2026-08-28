# VulnerableVault — Security Audit (ESTIAM Final Project)
```
Course: 4BLOCKC / E4CCSN — Blockchain Security  ·  ÉSTIAM Paris
Trainer: M. David de Paula Santos Silva
Group Number: 09
Members: Jihane FATHI, Arouna BA, Mohamed Amine ISSOUKTANE et Idriss QARQABI 
Date: 27/08/2026

```
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
<img width="1992" height="257" alt="image" src="https://github.com/user-attachments/assets/fec21cb0-c246-46e6-a0f8-61e088dfa165" />
<img width="1328" height="71" alt="image" src="https://github.com/user-attachments/assets/e9805033-19f0-4fae-b4fc-27b481a068c6" />
<img width="3034" height="1289" alt="image" src="https://github.com/user-attachments/assets/3345eac6-f7d7-4fb9-b84e-a877aa5a099a" />


## Compile

```bash
npx hardhat compile
```
<img width="1614" height="133" alt="image" src="https://github.com/user-attachments/assets/7ca49a49-879e-46d9-a054-3472319de862" />


## Run the tests

```bash
# everything (before + after)
npx hardhat testz
```
<img width="1868" height="563" alt="image" src="https://github.com/user-attachments/assets/d290448e-5445-4c62-8101-1b10c027b82f" />

```bash
# only the exploits against the vulnerable contract
npm run test:before
```
<img width="1555" height="491" alt="image" src="https://github.com/user-attachments/assets/a77b5427-6581-4729-a276-866c6628dac2" />

```bash
# only the checks against the fixed contract
npm run test:after
```
<img width="1551" height="508" alt="image" src="https://github.com/user-attachments/assets/45ed01e6-ecaa-420f-b072-3ec32bf93b3b" />

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
git remote add origin[ https://github.com/Jihane12/BlockchainSecurity-Project.git
git push -u origin main
```
<img width="2454" height="1752" alt="image" src="https://github.com/user-attachments/assets/114c7715-25be-4de0-9d08-f06f8f86a132" />

`node_modules/`, `cache/`, and `artifacts/` are already excluded via
`.gitignore` — anyone cloning the repo just needs to run `npm install`.

## Disclaimer

`VulnerableVault.sol` is intentionally insecure. Never deploy it, or funds
based on it, to mainnet or with real value.

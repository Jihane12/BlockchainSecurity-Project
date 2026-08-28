const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VulnerableVault (BEFORE fix)", function () {
  let vault, token, attacker;
  let owner, staker, attackerSigner, outsider;

  beforeEach(async function () {
    [owner, staker, attackerSigner, outsider] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockRewardToken");
    token = await Token.deploy();
    await token.waitForDeployment();

    const Vault = await ethers.getContractFactory("VulnerableVault");
    vault = await Vault.connect(owner).deploy(await token.getAddress());
    await vault.waitForDeployment();

    const Attacker = await ethers.getContractFactory("ReentrancyAttacker");
    attacker = await Attacker.connect(attackerSigner).deploy(await vault.getAddress());
    await attacker.waitForDeployment();
  });

  it("[Finding H3] reentrancy: attacker drains far more ETH than it deposited", async function () {
    // A legitimate staker seeds the vault with extra liquidity to steal.
    await vault.connect(staker).deposit({ value: ethers.parseEther("5") });

    // Attacker deposits only 1 ETH of its own.
    await attacker.connect(attackerSigner).attackDeposit({ value: ethers.parseEther("1") });

    const vaultBalanceBefore = await ethers.provider.getBalance(await vault.getAddress());
    expect(vaultBalanceBefore).to.equal(ethers.parseEther("6"));

    // Trigger the reentrant withdrawal chain.
    await attacker.connect(attackerSigner).attackWithdraw();

    const vaultBalanceAfter = await ethers.provider.getBalance(await vault.getAddress());
    const stolen = await attacker.stolenBalance();

    // Attacker walked away with more than its own 1 ETH stake.
    expect(stolen).to.be.gt(ethers.parseEther("1"));
    // Vault lost more than the attacker's own deposit.
    expect(vaultBalanceAfter).to.be.lt(ethers.parseEther("5"));
  });

  it("[Finding H2] anyone can change the owner (missing access control)", async function () {
    expect(await vault.owner()).to.equal(owner.address);

    await vault.connect(outsider).setOwner(outsider.address);

    expect(await vault.owner()).to.equal(outsider.address);
  });

  it("[Finding H1] anyone can drain all ETH via emergencyWithdraw (missing access control)", async function () {
    await vault.connect(staker).deposit({ value: ethers.parseEther("2") });
    expect(await ethers.provider.getBalance(await vault.getAddress())).to.equal(
      ethers.parseEther("2")
    );

    await vault.connect(outsider).emergencyWithdraw(outsider.address);

    expect(await ethers.provider.getBalance(await vault.getAddress())).to.equal(0);
  });
});

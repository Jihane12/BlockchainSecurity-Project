const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("VulnerableVaultFixed (AFTER fix)", function () {
  let vault, token, attacker;
  let owner, staker, attackerSigner, outsider;

  beforeEach(async function () {
    [owner, staker, attackerSigner, outsider] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("MockRewardToken");
    token = await Token.deploy();
    await token.waitForDeployment();

    const Vault = await ethers.getContractFactory("VulnerableVaultFixed");
    vault = await Vault.connect(owner).deploy(await token.getAddress());
    await vault.waitForDeployment();

    const Attacker = await ethers.getContractFactory("ReentrancyAttacker");
    attacker = await Attacker.connect(attackerSigner).deploy(await vault.getAddress());
    await attacker.waitForDeployment();
  });

  it("[Finding H3 fixed] reentrancy attempt reverts the whole transaction", async function () {
    await vault.connect(staker).deposit({ value: ethers.parseEther("5") });
    await attacker.connect(attackerSigner).attackDeposit({ value: ethers.parseEther("1") });

    const vaultBalanceBefore = await ethers.provider.getBalance(await vault.getAddress());
    expect(vaultBalanceBefore).to.equal(ethers.parseEther("6"));

    // The reentrant call now hits the reentrancy guard and the whole tx reverts.
    await expect(attacker.connect(attackerSigner).attackWithdraw()).to.be.reverted;

    // Nothing moved: vault balance and attacker balance unchanged.
    expect(await ethers.provider.getBalance(await vault.getAddress())).to.equal(
      vaultBalanceBefore
    );
    expect(await attacker.stolenBalance()).to.equal(0);
  });

  it("[Finding H2 fixed] setOwner reverts when called by a non-owner", async function () {
    await expect(
      vault.connect(outsider).setOwner(outsider.address)
    ).to.be.revertedWith("not owner");

    expect(await vault.owner()).to.equal(owner.address);
  });

  it("[Finding H1 fixed] emergencyWithdraw reverts when called by a non-owner", async function () {
    await vault.connect(staker).deposit({ value: ethers.parseEther("2") });

    await expect(
      vault.connect(outsider).emergencyWithdraw(outsider.address)
    ).to.be.revertedWith("not owner");

    expect(await ethers.provider.getBalance(await vault.getAddress())).to.equal(
      ethers.parseEther("2")
    );
  });

  it("[Finding H2] the legitimate owner can still change ownership", async function () {
    await vault.connect(owner).setOwner(outsider.address);
    expect(await vault.owner()).to.equal(outsider.address);
  });
});

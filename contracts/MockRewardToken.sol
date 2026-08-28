// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Minimal mock reward token — just enough to satisfy IRewardToken.transfer().
 * Not a real ERC20 (no approve/transferFrom needed for this test).
 * Deploy this first; its address is the `_rewardToken` constructor argument
 * for both VulnerableVault and VulnerableVaultFixed.
 */
contract MockRewardToken {
    mapping(address => uint256) public balanceOf;

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[to] += amount;
        return true;
    }
}

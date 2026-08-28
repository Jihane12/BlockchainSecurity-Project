// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * ============================================================================
 *  ESTIAM  -  Blockchain Security (4BLOCKC / E4CCSN)
 *  FINAL PROJECT  -  Fixed contract
 * ----------------------------------------------------------------------------
 *  Contract:  VulnerableVaultFixed
 *  Corrected version of VulnerableVault.sol. Each fix below is tagged with
 *  the finding it addresses (see the audit report for full details).
 * ============================================================================
 */

interface IRewardToken {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract VulnerableVaultFixed {
    // --- state -------------------------------------------------------------
    address public owner;
    IRewardToken public rewardToken;

    mapping(address => uint256) public balances;

    // FIX (Finding M2 - gameable stakers list): we no longer keep a
    // duplicate-friendly array of every deposit. Instead we track a
    // deduplicated list of *currently active* stakers (balance > 0), added
    // once on first deposit and removed once their balance hits zero.
    address[] public stakers;
    mapping(address => bool) public isStaker;
    mapping(address => uint256) private stakerIndex; // index+1 in `stakers`; 0 = not present

    uint256 public totalStaked;

    uint256 public lastRewardTime;
    uint256 public constant REWARD_INTERVAL = 1 days;
    uint256 public constant REWARD_AMOUNT = 100 ether;

    // FIX (Finding H3 - reentrancy): simple reentrancy guard.
    bool private locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed winner, uint256 amount);
    event RewardTransferFailed(address indexed winner, uint256 amount);
    event OwnerChanged(address indexed newOwner);

    constructor(address _rewardToken) {
        // FIX (Finding L1 - zero-address checks)
        require(_rewardToken != address(0), "zero reward token");
        owner = msg.sender;
        rewardToken = IRewardToken(_rewardToken);
        lastRewardTime = block.timestamp;
    }

    // --- access control ----------------------------------------------------
    // FIX (Finding H4 - tx.origin): authenticate the immediate caller
    // (msg.sender), not the original transaction sender. This is applied
    // below to setOwner() and emergencyWithdraw(), which is also the fix
    // for Findings H1 and H2 (those functions had NO access control at all
    // in the original contract).
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier noReentrant() {
        require(!locked, "reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // --- staking -----------------------------------------------------------
    function deposit() external payable {
        require(msg.value > 0, "zero deposit");
        _addStakerIfNew(msg.sender);

        balances[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * Withdraw part of your staked ETH.
     * FIX (Finding H3 - reentrancy): checks-effects-interactions is now
     * followed - state is updated BEFORE the external call, and a
     * reentrancy guard is applied as defense in depth. The `unchecked`
     * block was also removed so Solidity's built-in underflow checks apply.
     */
    function withdraw(uint256 amount) external noReentrant {
        require(amount > 0, "zero withdraw");
        require(balances[msg.sender] >= amount, "insufficient balance");

        // Effects first.
        balances[msg.sender] -= amount;
        totalStaked -= amount;

        // FIX (Finding M2): drop the user from the stakers list once their
        // stake reaches zero, so they can no longer win reward rounds.
        if (balances[msg.sender] == 0) {
            _removeStaker(msg.sender);
        }

        emit Withdrawn(msg.sender, amount);

        // Interaction last.
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "transfer failed");
    }

    // --- rewards -----------------------------------------------------------
    /**
     * Pick a staker and pay them REWARD_AMOUNT reward tokens, weighted by
     * their share of totalStaked.
     *
     * FIX (Finding M1 - weak randomness): this contract still uses on-chain
     * pseudo-randomness for simplicity, which is NOT safe for
     * high-value/adversarial production use. For a real deployment, replace
     * this selection mechanism with a verifiable randomness source such as
     * Chainlink VRF. This is flagged clearly here and in the audit report
     * rather than silently left in place.
     */
    function pickWinner() external {
        require(block.timestamp >= lastRewardTime + REWARD_INTERVAL, "too soon");
        require(stakers.length > 0, "no stakers");

        uint256 rand = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    blockhash(block.number - 1),
                    stakers.length,
                    address(this)
                )
            )
        );
        uint256 winnerIndex = rand % stakers.length;
        address winner = stakers[winnerIndex];

        lastRewardTime = block.timestamp;

        // FIX (Finding M3 - unchecked return value): check the return
        // value; if the transfer fails, do NOT emit RewardPaid (which would
        // falsely signal success) - emit a failure event instead so the
        // round can be retried/investigated.
        bool success = rewardToken.transfer(winner, REWARD_AMOUNT);
        if (success) {
            emit RewardPaid(winner, REWARD_AMOUNT);
        } else {
            emit RewardTransferFailed(winner, REWARD_AMOUNT);
        }
    }

    // --- administration ----------------------------------------------------
    /**
     * FIX (Finding H2): now restricted to the current owner, and rejects
     * the zero address (Finding L1).
     */
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        owner = newOwner;
        emit OwnerChanged(newOwner);
    }

    /**
     * FIX (Finding H1): now restricted to the owner. Kept as an emergency
     * recovery function for a real deployment you would also want a
     * timelock and/or multisig on `owner`, and ideally this function
     * should not be able to touch user-staked funds at all - noted in the
     * audit report as a residual-risk recommendation.
     */
    function emergencyWithdraw(address payable to) external onlyOwner {
        require(to != address(0), "zero recipient");
        uint256 bal = address(this).balance;
        (bool sent, ) = to.call{value: bal}("");
        require(sent, "rescue failed");
    }

    // --- views -------------------------------------------------------------
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function stakerCount() external view returns (uint256) {
        return stakers.length;
    }

    receive() external payable {
        require(msg.value > 0, "zero deposit");
        _addStakerIfNew(msg.sender);
        balances[msg.sender] += msg.value;
        totalStaked += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // --- internal helpers (Finding M2 fix) ----------------------------------
    function _addStakerIfNew(address user) private {
        if (!isStaker[user]) {
            isStaker[user] = true;
            stakers.push(user);
            stakerIndex[user] = stakers.length; // store as index+1
        }
    }

    function _removeStaker(address user) private {
        uint256 idxPlusOne = stakerIndex[user];
        if (idxPlusOne == 0) return; // not present

        uint256 idx = idxPlusOne - 1;
        uint256 lastIdx = stakers.length - 1;
        address lastAddr = stakers[lastIdx];

        // swap-and-pop
        stakers[idx] = lastAddr;
        stakerIndex[lastAddr] = idx + 1;

        stakers.pop();
        delete stakerIndex[user];
        isStaker[user] = false;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestToken
 * @author Anoy Roy Chowdhury - <anoy@daoplomats.org>
 * @notice ERC20 token with internal delegation and staking capabilities
 * @dev !!! DO NOT USE IN PRODUCTION !!! This contract is for testing purposes only
 */
contract DummyToken is ERC20, Ownable {
    // Delegation storage
    mapping(address => mapping(bytes32 => address)) public delegations;

    // Staking storage
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
        bool isStaked;
    }

    mapping(address => StakeInfo) public stakes;

    // Constants for staking
    uint256 public constant EARLY_WITHDRAWAL_FEE_PERCENTAGE = 10; // 10% fee
    uint256 public constant MIN_STAKING_DURATION = 0;
    uint256 public constant MAX_STAKING_DURATION = 365 days;

    // Events
    event DelegateSet(
        address indexed delegator,
        bytes32 indexed id,
        address delegate
    );
    event DelegateCleared(address indexed delegator, bytes32 indexed id);
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event WithdrawnEarly(address indexed user, uint256 amount, uint256 loss);
    event Withdrawn(address indexed user, uint256 amount);

    constructor() ERC20("Test Token", "f1inch") Ownable(msg.sender) {}

    /**
     * @notice Mint tokens to an address (only owner)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Set delegate for a specific ID
     * @param id The delegation ID
     * @param delegate The delegate address
     */
    function setDelegate(bytes32 id, address delegate) external {
        delegations[msg.sender][id] = delegate;
        emit DelegateSet(msg.sender, id, delegate);
    }

    /**
     * @notice Clear delegate for a specific ID
     * @param id The delegation ID
     */
    function clearDelegate(bytes32 id) external {
        delete delegations[msg.sender][id];
        emit DelegateCleared(msg.sender, id);
    }

    /**
     * @notice Get delegation for a specific delegator and ID
     * @param delegator The delegator address
     * @param id The delegation ID
     */
    function delegation(
        address delegator,
        bytes32 id
    ) external view returns (address) {
        return delegations[delegator][id];
    }

    /**
     * @notice Stake tokens
     * @param amount Amount of tokens to stake
     * @param duration Staking duration in seconds
     */
    function deposit(uint256 amount, uint256 duration) external {
        require(amount > 0, "Amount must be greater than 0");
        require(duration >= MIN_STAKING_DURATION, "Duration too short");
        require(duration <= MAX_STAKING_DURATION, "Duration too long");
        require(!stakes[msg.sender].isStaked, "Already staking");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, address(this), amount);

        stakes[msg.sender] = StakeInfo({
            amount: amount,
            startTime: block.timestamp,
            duration: duration,
            isStaked: true
        });

        emit Staked(msg.sender, amount, duration);
    }

    /**
     * @notice Calculate early withdrawal loss
     * @param account Address to check
     */
    function earlyWithdrawLoss(
        address account
    ) public view returns (uint256 loss, uint256 ret, bool canWithdraw) {
        StakeInfo memory stake = stakes[account];
        if (!stake.isStaked) {
            return (0, 0, false);
        }

        if (block.timestamp >= stake.startTime + stake.duration) {
            return (0, stake.amount, true);
        }

        loss = (stake.amount * EARLY_WITHDRAWAL_FEE_PERCENTAGE) / 100;
        ret = stake.amount - loss;
        canWithdraw = true;
    }

    /**
     * @notice Withdraw staked tokens early with a penalty
     * @param minReturn Minimum amount to receive
     * @param maxLoss Maximum acceptable loss
     */
    function earlyWithdraw(uint256 minReturn, uint256 maxLoss) external {
        (uint256 loss, uint256 ret, bool canWithdraw) = earlyWithdrawLoss(
            msg.sender
        );

        require(canWithdraw, "Cannot withdraw");
        require(loss <= maxLoss, "Loss exceeds maximum");
        require(ret >= minReturn, "Return below minimum");

        StakeInfo memory stake = stakes[msg.sender];
        delete stakes[msg.sender];

        _transfer(address(this), msg.sender, ret);
        emit WithdrawnEarly(msg.sender, stake.amount, loss);
    }

    /**
     * @notice Withdraw staked tokens after duration
     */
    function withdraw() external {
        StakeInfo memory stake = stakes[msg.sender];
        require(stake.isStaked, "No active stake");
        require(
            block.timestamp >= stake.startTime + stake.duration,
            "Staking period not ended"
        );

        uint256 amount = stake.amount;
        delete stakes[msg.sender];

        _transfer(address(this), msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
}

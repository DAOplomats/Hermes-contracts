// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./common/Singleton.sol";
import "./common/StorageAccessible.sol";
import "./interfaces/ISt1inch.sol";
import "./interfaces/IDelegateRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/ContractChecker.sol";

/**
 * @title Envoy - A contract that can be used to sub-delegate voting power to another address.
 * @author Anoy Roy Chowdhury - <anoy@daoplomats.org>
 */
contract Envoy is Singleton, StorageAccessible {
    using SafeERC20 for IERC20;

    event EnvoyInitialized(
        address indexed token,
        address indexed hermes,
        address indexed delegatee,
        uint256 amount,
        uint256 duration
    );

    IERC20 private _token;
    address private _hermes;
    address private _st1inch;
    address public _delegatee;

    // This constructor ensures that this contract can only be used as a singleton for Proxy contracts
    constructor() {
        _hermes = address(0x1);
    }

    // This modifier ensures that only the Hermes contract can call the function
    modifier onlyHermes() {
        require(msg.sender == _hermes, "Only Hermes can call this function");
        _;
    }

    /**
     * @notice Initializes the Envoy contract
     * @param token  The address of the token to be staked
     * @param hermes  The address of the Hermes contract
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param st1inch  The address of the 1inch staking contract
     * @param id  The id of the Snapshot space
     * @param delegatee  The address of the delegatee
     * @param amount  The amount of tokens to be staked
     * @param duration  The duration for which the tokens are to be staked
     */
    function initializeEnvoy(
        address token,
        address hermes,
        address delegateRegistry,
        address st1inch,
        bytes32 id,
        address delegatee,
        uint256 amount,
        uint256 duration
    ) public {
        require(hermes != address(0), "Invalid Hermes address");
        require(_hermes == address(0), "Already initialized");
        require(ContractChecker.isContract(hermes), "Invalid Hermes address");

        _hermes = hermes;
        _st1inch = st1inch;
        _delegatee = delegatee;
        _token = IERC20(token);

        ISt1inch(_st1inch).deposit(amount, duration);
        IDelegateRegistry(delegateRegistry).setDelegate(id, delegatee);

        emit EnvoyInitialized(token, hermes, delegatee, amount, duration);
    }

    /**
     * @notice Gets the recall loss incurred if the staked tokens are withdrawn early
     * @return loss  The loss incurred if the staked tokens are withdrawn early
     * @return ret  The amount that can be withdrawn early
     * @return canWithdraw  A boolean indicating whether the tokens can be withdrawn early
     */
    function earlyRecallLoss()
        external
        view
        returns (uint256 loss, uint256 ret, bool canWithdraw)
    {
        return ISt1inch(_st1inch).earlyWithdrawLoss(address(this));
    }

    /**
     * @notice Recalls the staked tokens
     * @param to  The address to which the staked tokens are to be transferred
     */
    function recall(address to) external onlyHermes {
        ISt1inch(_st1inch).withdraw();

        _token.safeTransfer(to, _token.balanceOf(address(this)));
    }

    /**
     * @notice Recalls the staked tokens early
     * @param to  The address to which the staked tokens are to be transferred
     * @param minReturn  The minimum amount that should be returned
     * @param maxLoss  The maximum loss that can be incurred
     */
    function earlyRecall(
        address to,
        uint256 minReturn,
        uint256 maxLoss
    ) external onlyHermes {
        ISt1inch(_st1inch).earlyWithdraw(minReturn, maxLoss);

        _token.safeTransfer(to, _token.balanceOf(address(this)));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for St1inch Staking Contract
 * @notice Defines the external methods and events for the 1inch staking contract
 */
interface ISt1inch {
    function deposit(uint256 amount, uint256 duration) external;

    function earlyWithdraw(uint256 minReturn, uint256 maxLoss) external;

    function earlyWithdrawLoss(
        address account
    ) external view returns (uint256 loss, uint256 ret, bool canWithdraw);

    function withdraw() external;
}

// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Interface for DelegateRegistry Contract
 * @notice Defines the external methods and events for the delegate registry
 */
interface IDelegateRegistry {
    function delegation(
        address delegator,
        bytes32 id
    ) external view returns (address);

    function setDelegate(bytes32 id, address delegate) external;

    function clearDelegate(bytes32 id) external;
}

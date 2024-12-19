// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./proxies/Proxy.sol";
import "./Hermes.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/ContractChecker.sol";

/**
 * @title HermesProxyFactory - A contract that can be used to fund and deploy Hermes contracts
 * @author Anoy Roy Chowdhury - <anoy@daoplomats.org>
 * @notice This contract is used to deploy Hermes contracts and fund them with tokens using CREATE2.
 *         Further, Lead Delegatees can deploy Envoys which can be used to sub-delegate voting power to another address.
 *         Hermes Proxy factory provides deployers with the ability to recall tokens from the Hermes contracts.
 */
contract HermesProxyFactory {
    using SafeERC20 for IERC20;

    event HermesCreated(address indexed hermes, address indexed admin);

    address private HERMES_SINGLETON;
    address private ENVOY_SINGLETON;
    IERC20 private _token;
    address private _st1inch;
    address private _delegateRegistry;
    bytes32 private _id;

    // Initialize the HermesProxyFactory contract
    constructor(
        address token,
        address st1inch,
        address delegateRegistry,
        bytes32 id
    ) {
        require(token != address(0), "Token address cannot be zero");
        require(st1inch != address(0), "St1inch address cannot be zero");
        require(
            delegateRegistry != address(0),
            "DelegateRegistry address cannot be zero"
        );

        _token = IERC20(token);
        _st1inch = st1inch;
        _delegateRegistry = delegateRegistry;
        _id = id;

        HERMES_SINGLETON = address(new Hermes());
        ENVOY_SINGLETON = address(new Envoy());
    }

    /**
     * @notice Deploys a new Hermes contract
     * @param token  The address of the token to be staked
     * @param st1inch  The address of the 1inch staking contract
     * @param leadDelegatee  The address of the lead delegatee
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param id  The id of the Snapshot space
     * @param maxSubDelegators  The maximum number of sub-delegators
     * @param maxDuration  The maximum duration for which the tokens are to be staked
     * @param salt  The salt value for CREATE2
     */
    function _deployHermes(
        address token,
        address st1inch,
        address leadDelegatee,
        address delegateRegistry,
        bytes32 id,
        uint256 maxSubDelegators,
        uint256 maxDuration,
        bytes32 salt
    ) internal returns (Proxy proxy) {
        require(
            ContractChecker.isContract(HERMES_SINGLETON),
            "Invalid HERMES Singleton address"
        );

        bytes memory deploymentData = abi.encodePacked(
            type(Proxy).creationCode,
            uint256(uint160(HERMES_SINGLETON))
        );
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(
                0x0,
                add(0x20, deploymentData),
                mload(deploymentData),
                salt
            )
        }
        require(address(proxy) != address(0), "Create2 call failed");

        bytes memory initializer = getHermesInitializer(
            token,
            st1inch,
            leadDelegatee,
            delegateRegistry,
            id,
            maxSubDelegators,
            maxDuration
        );

        // solhint-disable-next-line no-inline-assembly
        assembly {
            if eq(
                call(
                    gas(),
                    proxy,
                    0,
                    add(initializer, 0x20),
                    mload(initializer),
                    0,
                    0
                ),
                0
            ) {
                revert(0, 0)
            }
        }
    }

    /**
     * @notice Deploys a new Hermes contract and funds it with the specified amount of tokens
     * @param amount  The amount of tokens to be staked
     * @param leadDelegatee  The address of the lead delegatee
     * @param maxSubDelegators  The maximum number of sub-delegators
     * @param maxDuration  The maximum duration for which the tokens are to be staked
     * @param salt  The salt value for CREATE2
     */
    function fundAndDeployHermes(
        uint256 amount,
        address leadDelegatee,
        uint256 maxSubDelegators,
        uint256 maxDuration,
        uint256 salt
    ) external returns (Proxy proxy) {
        require(
            leadDelegatee != address(0),
            "Lead delegatee cannot be zero address"
        );

        require(amount > 0, "Amount must be greater than 0");
        require(
            IERC20(_token).balanceOf(msg.sender) >= amount,
            "Insufficient balance"
        );

        bytes32 _salt = keccak256(
            abi.encodePacked(msg.sender, leadDelegatee, salt)
        );

        proxy = _deployHermes(
            address(_token),
            _st1inch,
            leadDelegatee,
            _delegateRegistry,
            _id,
            maxSubDelegators,
            maxDuration,
            _salt
        );

        IERC20(_token).safeTransferFrom(msg.sender, address(proxy), amount);

        emit HermesCreated(address(proxy), msg.sender);
    }

    /**
     * @notice Recalls the tokens from the Hermes contract
     * @param leadDelegatee  The address of the lead delegatee
     * @param salt  The salt value for CREATE2
     * @param envoy  The address of the envoy
     * @param to  The address to which the tokens are to be transferred
     */
    function recall(
        address leadDelegatee,
        uint256 salt,
        address envoy,
        address to
    ) external {
        address hermes = getHermes(msg.sender, leadDelegatee, salt);

        require(
            envoy != address(0) && ContractChecker.isContract(envoy),
            "Invalid envoy address"
        );

        Hermes(hermes).recall(envoy, to);
    }

    /**
     * @notice Recalls all the tokens from the Hermes contract
     * @param leadDelegatee  The address of the lead delegatee
     * @param salt  The salt value for CREATE2
     * @param to  The address to which the tokens are to be transferred
     */
    function recallAll(
        address leadDelegatee,
        uint256 salt,
        address to
    ) external {
        address hermes = getHermes(msg.sender, leadDelegatee, salt);

        Hermes(hermes).recallAll(to);
    }

    /**
     * @notice Recalls the staked tokens early
     * @param leadDelegatee  The address of the lead delegatee
     * @param salt  The salt value for CREATE2
     * @param envoy  The address of the envoy
     * @param to  The address to which the tokens are to be transferred
     * @param minReturn  The minimum amount of tokens to be returned
     * @param maxLoss  The maximum loss that can be incurred
     */
    function recallEarly(
        address leadDelegatee,
        uint256 salt,
        address envoy,
        address to,
        uint256 minReturn,
        uint256 maxLoss
    ) external {
        address hermes = getHermes(msg.sender, leadDelegatee, salt);

        require(
            envoy != address(0) && ContractChecker.isContract(envoy),
            "Invalid envoy address"
        );

        Hermes(hermes).recallEarly(envoy, to, minReturn, maxLoss);
    }

    /**
     * @notice Recalls all the staked tokens early
     * @param owner  The address of the owner
     * @param leadDelegatee  The address of the lead delegatee
     * @param salt  The salt value for CREATE2
     */
    function getHermes(
        address owner,
        address leadDelegatee,
        uint256 salt
    ) public view returns (address) {
        bytes32 _salt = keccak256(abi.encodePacked(owner, leadDelegatee, salt));

        bytes memory deploymentData = abi.encodePacked(
            type(Proxy).creationCode,
            uint256(uint160(HERMES_SINGLETON))
        );

        // Calculate the address of the proxy contract using CREATE2
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(deploymentData)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Gets the initializer data for the Hermes contract
     * @param token  The address of the token to be staked
     * @param st1inch  The address of the 1inch staking contract
     * @param leadDelegatee  The address of the lead delegatee
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param id  The id of the Snapshot space
     * @param maxSubDelegators  The maximum number of sub-delegators
     * @param maxDuration  The maximum duration for which the tokens are to be staked
     */
    function getHermesInitializer(
        address token,
        address st1inch,
        address leadDelegatee,
        address delegateRegistry,
        bytes32 id,
        uint256 maxSubDelegators,
        uint256 maxDuration
    ) private view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                Hermes.initializeHermes.selector,
                token,
                st1inch,
                leadDelegatee,
                delegateRegistry,
                id,
                maxSubDelegators,
                maxDuration,
                ENVOY_SINGLETON
            );
    }
}

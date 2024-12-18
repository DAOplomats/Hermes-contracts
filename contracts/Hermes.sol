// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./common/Singleton.sol";
import "./common/StorageAccessible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./base/EnvoyManager.sol";
import "./Envoy.sol";
import "./proxies/Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/ContractChecker.sol";

/**
 * @title Hermes - A contract that enables the lead delegatee to sub-delegate voting power to other addresses.
 * @author Anoy Roy Chowdhury - <anoy@daoplomats.org>
 */
contract Hermes is Singleton, StorageAccessible, EnvoyManager {
    using SafeERC20 for IERC20;

    event SubDelegate(
        address indexed delegatee,
        uint256 amount,
        uint256 duration
    );

    event HermesInitialized(address _leadDelegatee);

    address public factory;
    IERC20 private _token;
    address private _st1inch;
    address public _leadDelegatee;
    address private _delegateRegistry;
    bytes32 private _id;
    uint256 public MAX_SUB_DELEGATORS;
    uint256 public MAX_DURATION;
    address private ENVOY_SINGLETON;

    // This constructor ensures that this contract can only be used as a singleton for Proxy contracts
    constructor() {
        _leadDelegatee = address(0x1);

        ENVOY_SINGLETON = address(new Envoy());
    }

    // This modifier ensures that only the Lead Delegatee can call the function
    modifier onlyLeadDelegatee() {
        require(
            msg.sender == _leadDelegatee,
            "Only Lead Delegatee can call this function"
        );
        _;
    }

    // This modifier ensures that only the Factory contract can call the function
    modifier onlyFactory() {
        require(msg.sender == factory, "Only Factory can call this function");
        _;
    }

    /**
     * @notice Initializes the Hermes contract
     * @param token  The address of the token to be staked
     * @param st1inch  The address of the 1inch staking contract
     * @param leadDelegatee  The address of the lead delegatee
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param id  The id of the Snapshot space
     * @param maxSubDelegators  The maximum number of sub-delegators
     * @param maxDuration  The maximum duration for which the tokens are to be staked
     */
    function initializeHermes(
        address token,
        address st1inch,
        address leadDelegatee,
        address delegateRegistry,
        bytes32 id,
        uint256 maxSubDelegators,
        uint256 maxDuration
    ) public {
        require(_leadDelegatee == address(0), "Already initialized");
        require(
            ContractChecker.isContract(msg.sender),
            "Invalid factory address"
        );

        require(token != address(0), "Token address cannot be zero");
        require(st1inch != address(0), "St1inch address cannot be zero");
        require(leadDelegatee != address(0), "Lead delegatee cannot be zero");
        require(
            delegateRegistry != address(0),
            "DelegateRegistry cannot be zero"
        );

        factory = msg.sender;
        _token = IERC20(token);
        _st1inch = st1inch;
        _leadDelegatee = leadDelegatee;
        _id = id;
        _delegateRegistry = delegateRegistry;
        MAX_SUB_DELEGATORS = maxSubDelegators;
        MAX_DURATION = maxDuration;

        emit HermesInitialized(leadDelegatee);
    }

    /**
     * @notice Creates a new envoy contract with specified delegatee, amount and duration
     * @param token  The address of the token to be staked
     * @param hermes  The address of the Hermes contract
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param st1inch  The address of the 1inch staking contract
     * @param id  The id of the Snapshot space
     * @param delegatee  The address of the delegatee
     * @param amount  The amount of tokens to be staked
     * @param duration  The duration for which the tokens are to be staked
     * @param salt  The salt for the create2 call
     */
    function _deployEnvoy(
        address token,
        address hermes,
        address delegateRegistry,
        address st1inch,
        bytes32 id,
        address delegatee,
        uint256 amount,
        uint256 duration,
        bytes32 salt
    ) internal returns (Proxy proxy) {
        require(
            ContractChecker.isContract(ENVOY_SINGLETON),
            "Invalid Envoy Singleton address"
        );

        bytes memory deploymentData = abi.encodePacked(
            type(Proxy).creationCode,
            uint256(uint160(ENVOY_SINGLETON))
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

        bytes memory initializer = getEnvoyInitializer(
            token,
            hermes,
            delegateRegistry,
            st1inch,
            id,
            delegatee,
            amount,
            duration
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
     * @notice Sub-delegates voting power to a new address
     * @param delegatee  The address of the delegatee
     * @param amount  The amount of tokens to be staked
     * @param duration  The duration for which the tokens are to be staked
     */
    function subDelegate(
        address delegatee,
        uint256 amount,
        uint256 duration
    ) public onlyLeadDelegatee {
        require(delegatee != address(0), "Delegatee cannot be zero address");
        require(
            delegatee != _leadDelegatee,
            "Delegatee cannot be lead delegatee"
        );
        require(
            delegatee != address(this),
            "Delegatee cannot be this contract"
        );

        require(envoyCount < MAX_SUB_DELEGATORS, "Max sub-delegators reached");
        require(!isEnvoy(delegatee), "Delegatee is already an Envoy");
        require(duration <= MAX_DURATION, "Invalid duration");

        _token.safeTransferFrom(msg.sender, address(this), amount);

        bytes32 salt = keccak256(abi.encodePacked(_leadDelegatee, delegatee));

        Proxy envoy = _deployEnvoy(
            address(_token),
            address(this),
            _delegateRegistry,
            _st1inch,
            _id,
            delegatee,
            amount,
            duration,
            salt
        );

        addEnvoy(address(envoy));

        emit SubDelegate(delegatee, amount, duration);
    }

    /**
     * @notice Sub-delegates voting power to multiple addresses
     * @param delegatees  The addresses of the delegatees
     * @param amounts  The amounts of tokens to be staked
     * @param durations  The durations for which the tokens are to be staked
     */
    function subDelegateMultiple(
        address[] calldata delegatees,
        uint256[] calldata amounts,
        uint256[] calldata durations
    ) external onlyLeadDelegatee {
        require(
            delegatees.length == amounts.length &&
                delegatees.length == durations.length,
            "Invalid input"
        );

        require(
            envoyCount + delegatees.length <= MAX_SUB_DELEGATORS,
            "Max sub-delegators reached"
        );

        for (uint256 i = 0; i < delegatees.length; i++) {
            subDelegate(delegatees[i], amounts[i], durations[i]);
        }
    }

    /**
     * @notice Recalls all tokens from the envoy contracts
     * @param envoy  The address of the envoy
     * @param to  The address to which the tokens are to be transferred
     */
    function recall(address envoy, address to) public onlyFactory {
        require(to != address(0), "Recipient cannot be zero address");
        require(envoy != address(0) && isEnvoy(envoy), "Invalid Envoy address");

        Envoy(envoy).recall(to);

        _token.safeTransfer(to, _token.balanceOf(address(this)));
    }

    /**
     * @notice Recalls all tokens from the envoy contracts
     * @dev WARNING! This function may not work if recall or earlyRecall function are called before this function
     * @param to  The address to which the tokens are to be transferred
     */
    function recallAll(address to) public onlyFactory {
        address envoy = envoys[SENTINEL_ENVOY];
        while (envoy != SENTINEL_ENVOY && envoy != address(0)) {
            Envoy(envoy).recall(to);
            envoy = envoys[envoy];
        }

        _token.safeTransfer(to, _token.balanceOf(address(this)));
    }

    /**
     * @notice Recalls all tokens from the envoy contracts
     * @param envoy  The address of the envoy
     * @param to  The address to which the tokens are to be transferred
     * @param minReturn  The minimum amount that should be returned
     * @param maxLoss  The maximum loss that can be incurred
     */
    function recallEarly(
        address envoy,
        address to,
        uint256 minReturn,
        uint256 maxLoss
    ) public onlyFactory {
        require(to != address(0), "Recipient cannot be zero address");
        require(envoy != address(0) && isEnvoy(envoy), "Invalid Envoy address");

        Envoy(envoy).earlyRecall(to, minReturn, maxLoss);

        _token.safeTransfer(to, _token.balanceOf(address(this)));
    }

    /**
     * @notice Gets the envoy initializer
     * @param token  The address of the token to be staked
     * @param hermes  The address of the Hermes contract
     * @param delegateRegistry  The address of the Snapshot DelegateRegistry contract
     * @param st1inch  The address of the 1inch staking contract
     * @param id  The id of the Snapshot space
     * @param delegatee  The address of the delegatee
     * @param amount  The amount of tokens to be staked
     * @param duration  The duration for which the tokens are to be staked
     */
    function getEnvoyInitializer(
        address token,
        address hermes,
        address delegateRegistry,
        address st1inch,
        bytes32 id,
        address delegatee,
        uint256 amount,
        uint256 duration
    ) private pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                Envoy.initializeEnvoy.selector,
                token,
                hermes,
                delegateRegistry,
                st1inch,
                id,
                delegatee,
                amount,
                duration
            );
    }
}

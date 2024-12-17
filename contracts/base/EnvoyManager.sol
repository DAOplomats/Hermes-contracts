// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title EnvoyManager - A contract that manages the envoys of the Hermes contract.
 * @author Anoy Roy Chowdhury - <anoy@daoplomats.org>
 */
abstract contract EnvoyManager {
    address internal constant SENTINEL_ENVOY = address(0x1);

    mapping(address => address) internal envoys;

    uint256 public envoyCount;

    /**
     * @notice Initializes the linked list with the sentinel value.
     */
    constructor() {
        envoys[SENTINEL_ENVOY] = SENTINEL_ENVOY;
    }

    /**
     * @notice Adds a new envoy to the linked list.
     * @param envoy The address of the envoy to be added.
     */
    function addEnvoy(address envoy) internal {
        require(
            envoy != address(0) || envoy != SENTINEL_ENVOY,
            "Invalid Envoy"
        );
        require(envoys[envoy] == address(0), "Member already exists");
        envoys[envoy] = envoys[SENTINEL_ENVOY];
        envoys[SENTINEL_ENVOY] = envoy;

        envoyCount++;
    }

    /**
     * @notice Checks if an envoy exists in the linked list.
     * @param envoy The address of the envoy to be checked.
     */
    function isEnvoy(address envoy) public view returns (bool) {
        return SENTINEL_ENVOY != envoy && envoys[envoy] != address(0);
    }

    /**
     * @notice Returns the envoys in the linked list paginated.
     * @param start The start of the linked list or the sentinel address.
     * @param pageSize The size of the page.
     */
    function getEnvoysPaginated(
        address start,
        uint256 pageSize
    ) external view returns (address[] memory array, address next) {
        if (start != SENTINEL_ENVOY && !isEnvoy(start))
            revert("Invalid start address");
        if (pageSize == 0) revert("Invalid page size");
        // Init array with max page size
        array = new address[](pageSize);

        // Populate return array
        uint256 _envoyCount = 0;
        next = envoys[start];
        while (
            next != address(0) &&
            next != SENTINEL_ENVOY &&
            _envoyCount < pageSize
        ) {
            array[envoyCount] = next;
            next = envoys[next];
            _envoyCount++;
        }

        if (next != SENTINEL_ENVOY) {
            next = array[_envoyCount - 1];
        }
        // Set correct size of returned array
        /* solhint-disable no-inline-assembly */
        /// @solidity memory-safe-assembly
        assembly {
            mstore(array, _envoyCount)
        }
        /* solhint-enable no-inline-assembly */
    }
}

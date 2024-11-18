// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSExtUpgradeable } from "../common/UUPSExtUpgradeable.sol";
import { LiquidityPoolAccountable } from "./LiquidityPoolAccountable.sol";
import { Error } from "../common/libraries/Error.sol";

/// @title LiquidityPoolAccountableUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the accountable liquidity pool contract.
contract LiquidityPoolAccountableUUPS is LiquidityPoolAccountable, UUPSExtUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The upgrade validation function for the UUPSExtUpgradeable contract.
     * @param newImplementation The address of the new implementation.
     */
    function _validateUpgrade(address newImplementation) internal view override onlyRole(OWNER_ROLE) {
        try LiquidityPoolAccountableUUPS(newImplementation).proveLiquidityPool() {} catch {
            revert Error.ImplementationAddressInvalid();
        }
    }
}

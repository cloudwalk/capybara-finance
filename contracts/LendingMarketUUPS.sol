// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSExtUpgradeable } from "./common/UUPSExtUpgradeable.sol";
import { LendingMarket } from "./LendingMarket.sol";
import { Error } from "./common/libraries/Error.sol";

/// @title LendingMarketUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the lending market contract.
contract LendingMarketUUPS is LendingMarket, UUPSExtUpgradeable {
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
        try LendingMarketUUPS(newImplementation).proveLendingMarket() {} catch {
            revert Error.ImplementationAddressInvalid();
        }
    }
}

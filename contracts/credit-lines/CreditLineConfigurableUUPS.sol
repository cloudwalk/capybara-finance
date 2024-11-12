// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSExtUpgradeable } from "../common/UUPSExtUpgradeable.sol";
import { CreditLineConfigurable } from "./CreditLineConfigurable.sol";

import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";

/// @title CreditLineConfigurableUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the configurable credit line contract.
contract CreditLineConfigurableUUPS is CreditLineConfigurable, UUPSExtUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The upgrade validation function for the UUPSExtUpgradeable contract.
     * @param newImplementation The address of the new implementation.
     */
    function _validateUpgrade(address newImplementation) internal override onlyRole(OWNER_ROLE) {
        try ICreditLine(newImplementation).proveCreditLine() {} catch {
            revert CreditLine_ImplementationAddressInvalid();
        }
    }
}

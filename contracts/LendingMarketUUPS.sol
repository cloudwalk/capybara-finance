// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { UUPSExtUpgradeable } from "./common/UUPSExtUpgradeable.sol";

import { LendingMarket } from "./LendingMarket.sol";
import { ILendingMarket } from "./common/interfaces/core/ILendingMarket.sol";

/// @title LendingMarketUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the lending market contract.
contract LendingMarketUUPS is LendingMarket, UUPSExtUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSExtUpgradeable
    function _validateUpgrade(address newImplementation) internal override onlyRole(OWNER_ROLE) {
        try ILendingMarket(newImplementation).proveLendingMarket() {} catch {
            revert LendingMarket_ImplementationAddressInvalid();
        }
    }
}

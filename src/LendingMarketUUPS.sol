// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { LendingMarket } from "./LendingMarket.sol";

/// @title LendingMarketUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Upgradeable version of the lending market contract.
contract LendingMarketUUPS is LendingMarket, UUPSUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
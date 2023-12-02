// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {LendingMarket} from "./LendingMarket.sol";

/// @title LendingMarketUUPS contract
/// @notice Implementation of the upgradeable lending market contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketUUPS is LendingMarket, UUPSUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { LiquidityPoolFactory } from "./LiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the liquidity pool factory contract.
contract LiquidityPoolFactoryUUPS is LiquidityPoolFactory, UUPSUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}

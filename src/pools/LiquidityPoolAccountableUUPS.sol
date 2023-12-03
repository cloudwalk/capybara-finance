// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {LiquidityPoolAccountable} from "./LiquidityPoolAccountable.sol";

/// @title LiquidityPoolAccountableUUPS contract
/// @notice Upgradeable version of the accountable liquidity pool contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolAccountableUUPS is LiquidityPoolAccountable, UUPSUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

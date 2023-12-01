// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {LiquidityPoolAccountable} from "./LiquidityPoolAccountable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title LiquidityPoolAccountableUUPS contract
/// @notice Implementation of an upgradeable version of the accountable liquidity pool contract
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

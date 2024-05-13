// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { LiquidityPoolAccountable } from "./LiquidityPoolAccountable.sol";

/// @title LiquidityPoolAccountableUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the accountable liquidity pool contract.
contract LiquidityPoolAccountableUUPS is LiquidityPoolAccountable, UUPSUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(OWNER_ROLE) { }
}

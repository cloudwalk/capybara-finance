// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { UUPSExtUpgradeable } from "../common/UUPSExtUpgradeable.sol";
import { LiquidityPoolAccountable } from "./LiquidityPoolAccountable.sol";

import { ILiquidityPool } from "../common/interfaces/core/ILiquidityPool.sol";

/// @title LiquidityPoolAccountableUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Upgradeable version of the accountable liquidity pool contract.
contract LiquidityPoolAccountableUUPS is LiquidityPoolAccountable, UUPSExtUpgradeable {
    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc UUPSExtUpgradeable
    function _validateUpgrade(address newImplementation) internal override onlyRole(OWNER_ROLE) {
        try ILiquidityPool(newImplementation).proveLiquidityPool() {} catch {
            revert LiquidityPool_ImplementationAddressInvalid();
        }
    }
}

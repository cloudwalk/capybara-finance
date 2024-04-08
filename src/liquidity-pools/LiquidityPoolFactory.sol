// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { ILiquidityPool } from "../common/interfaces/core/ILiquidityPool.sol";
import { ILiquidityPoolFactory } from "../common/interfaces/ILiquidityPoolFactory.sol";

import { LiquidityPoolAccountable } from "./LiquidityPoolAccountable.sol";

/// @title LiquidityPoolFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the liquidity pool factory contract.
contract LiquidityPoolFactory is OwnableUpgradeable, ILiquidityPoolFactory {
    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @dev Thrown when the requested liquidity pool kind is not supported.
    error UnsupportedKind();

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @dev Initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function initialize(address registry_) external initializer {
        __LiquidityPoolFactory_init(registry_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function __LiquidityPoolFactory_init(address registry_) internal onlyInitializing {
        __Ownable_init_unchained(registry_);
        __LiquidityPoolFactory_init_unchained();
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    function __LiquidityPoolFactory_init_unchained() internal onlyInitializing { }

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolFactory
    function createLiquidityPool(
        address market,
        address lender,
        uint16 kind,
        bytes calldata data
    ) external onlyOwner returns (address) {
        data; // To prevent compiler warning about unused variable

        if (kind != 1) {
            revert UnsupportedKind();
        }

        LiquidityPoolAccountable liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(market, lender);

        emit LiquidityPoolCreated(market, lender, kind, address(liquidityPool));

        return address(liquidityPool);
    }

    /// @inheritdoc ILiquidityPoolFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}

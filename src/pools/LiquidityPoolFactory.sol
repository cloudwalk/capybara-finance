// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {ILiquidityPool} from "../interfaces/core/ILiquidityPool.sol";
import {ILiquidityPoolFactory} from "../interfaces/ILiquidityPoolFactory.sol";
import {LiquidityPoolAccountable} from "./LiquidityPoolAccountable.sol";

/// @title LiquidityPoolFactory contract
/// @notice Implementation of the liquidity pool factory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactory is OwnableUpgradeable, PausableUpgradeable, ILiquidityPoolFactory {
    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the requested liquidity pool kind is not supported
    error UnsupportedKind();

    /************************************************
     *  Initializers
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param registry_ The address of the associated lending market
    function initialize(address registry_) external initializer {
        __LiquidityPoolFactory_init(registry_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param registry_ The address of the associated lending market
    function __LiquidityPoolFactory_init(address registry_) internal onlyInitializing {
        __Ownable_init_unchained(registry_);
        __Pausable_init_unchained();
        __LiquidityPoolFactory_init_unchained();
    }

    /// @notice Unchained internal initializer of the upgradable contract
    function __LiquidityPoolFactory_init_unchained() internal onlyInitializing {}

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ILiquidityPoolFactory
    function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data)
        external
        onlyOwner
        returns (address)
    {
        if (kind != 1) {
            revert UnsupportedKind();
        }

        LiquidityPoolAccountable liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(market, lender);

        emit CreateLiquidityPool(market, lender, kind, address(liquidityPool));

        return address(liquidityPool);
    }

    /// @inheritdoc ILiquidityPoolFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}

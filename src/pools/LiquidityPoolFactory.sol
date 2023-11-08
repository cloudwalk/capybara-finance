// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ILiquidityPool} from "../interfaces/core/ILiquidityPool.sol";
import {ILiquidityPoolFactory} from "../interfaces/ILiquidityPoolFactory.sol";

import {LiquidityPoolAccountable} from "./LiquidityPoolAccountable.sol";

/// @title LiquidityPoolFactory contract
/// @notice Implementation of the liquidity pool factory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactory is Ownable, ILiquidityPoolFactory {
    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the requested liquidity pool kind is not supported
    /// @param kind The kind of liquidity pool that is not supported
    error UnsupportedKind(uint16 kind);

    /************************************************
     *  Constructor
     ***********************************************/

    /// @notice Contract constructor
    /// @param registry_ The address of the associated lending market
    constructor(address registry_) Ownable(registry_) {}

    /************************************************
     *  Functions
     ***********************************************/

    /// @inheritdoc ILiquidityPoolFactory
    function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data)
        external
        onlyOwner
        returns (address liquidityPool)
    {
        if (kind != 1) {
            revert UnsupportedKind(kind);
        }

        liquidityPool = address(new LiquidityPoolAccountable(market, lender));

        emit LiquidityPoolCreated(market, lender, kind, liquidityPool);
    }

    /// @inheritdoc ILiquidityPoolFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}

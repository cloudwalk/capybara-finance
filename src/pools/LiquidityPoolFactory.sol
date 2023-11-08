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
     *  ERRORS
     ***********************************************/

    /// @notice Thrown when the requested liquidity pool kind is not supported
    /// @param kind The kind of liquidity pool that is not supported
    error UnsupportedKind(uint16 kind);

    /************************************************
     *  CONSTRUCTOR
     ***********************************************/

    /// @notice Contract constructor
    /// @param registry_ The address of the associated lending market
    constructor(address registry_) Ownable(registry_) {}

    /************************************************
     *  FUNCTIONS
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

        emit LiquidityPoolCreated(msg.sender, kind, liquidityPool);
    }
}

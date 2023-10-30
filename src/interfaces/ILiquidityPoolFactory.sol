// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title ILiquidityPoolFactory interface
/// @notice Defines the liquidity pool factory functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ILiquidityPoolFactory {
    /************************************************
     *  EVENTS
     ***********************************************/

    /// @notice Emitted when a new liquidity pool is created
    /// @param market The address of the associated lending market
    /// @param kind The kind of liquidity pool
    /// @param liquidityPool The address of the created liquidity pool contract
    event LiquidityPoolCreated(address indexed market, uint16 indexed kind, address liquidityPool);

    /************************************************
     *  FUNCTIONS
     ***********************************************/

    /// @notice Creates a new liquidity pool
    /// @param market The address of the market
    /// @param lender The address of the lender
    /// @param kind The kind of liquidity pool to create
    /// @param data The data to configure the liquidity pool
    /// @return The address of the created liquidity pool contract
    function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address);
}

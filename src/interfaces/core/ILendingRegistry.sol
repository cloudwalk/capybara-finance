// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title ILendingRegistry interface
/// @notice Defines the lending registry functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ILendingRegistry {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when a new credit line is created
    /// @param lender The address of the credit line lender
    /// @param creditLine The address of the credit line contract
    event CreditLineCreated(address indexed lender, address creditLine);

    /// @notice Emitted when a new liquidity pool is created
    /// @param lender The address of the liquidity pool lender
    /// @param liquidityPool The address of the liquidity pool contract
    event LiquidityPoolCreated(address indexed lender, address liquidityPool);

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Creates a new credit line
    /// @param kind The kind of the credit line
    /// @param token The address of the credit line token
    function createCreditLine(uint16 kind, address token) external;

    /// @notice Creates a new liquidity pool
    /// @param kind The kind of the liquidity pool
    function createLiquidityPool(uint16 kind) external;

    /// @notice Returns the address of the credit line factory
    function creditLineFactory() external view returns (address);

    /// @notice Returns the address of the liquidity pool factory
    function liquidityPoolFactory() external view returns (address);

    /// @notice Returns the address of the associated lending market
    function market() external view returns (address);
}

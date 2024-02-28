// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title ILendingRegistry interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the lending registry contract functions and events.
interface ILendingRegistry {
    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @notice Creates a new credit line.
    /// @param kind The kind of the credit line to create.
    /// @param token The address of the credit line token.
    function createCreditLine(uint16 kind, address token) external;

    /// @notice Creates a new liquidity pool.
    /// @param kind The kind of the liquidity pool to create.
    function createLiquidityPool(uint16 kind) external;

    /// @notice Returns the address of the credit line factory.
    function creditLineFactory() external view returns (address);

    /// @notice Returns the address of the liquidity pool factory.
    function liquidityPoolFactory() external view returns (address);

    /// @notice Returns the address of the associated lending market.
    function market() external view returns (address);
}

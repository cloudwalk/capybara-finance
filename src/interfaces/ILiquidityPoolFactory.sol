// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title ILiquidityPoolFactory interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the liquidity pool factory contract functions and events
interface ILiquidityPoolFactory {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when a new liquidity pool is created
    /// @param market The address of the associated lending market
    /// @param lender The address of the liquidity pool lender
    /// @param kind The kind of the created liquidity pool
    /// @param liquidityPool The address of the created liquidity pool
    event CreateLiquidityPool(
        address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool
    );

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Creates a new liquidity pool
    /// @param market The address of the lending market
    /// @param lender The address of the liquidity pool lender
    /// @param kind The kind of liquidity pool to create
    /// @param data The data to configure the liquidity pool
    /// @return The address of the created liquidity pool contract
    function createLiquidityPool(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address);

    /// @notice Returns the list of supported liquidity pool kinds
    function supportedKinds() external view returns (uint16[] memory);
}

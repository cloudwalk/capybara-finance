// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title LendingRegistryStorage contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the storage layout for the lending registry contract
abstract contract LendingRegistryStorage {
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @notice The address of the lending market
    address internal _market;

    /// @notice The address of the credit line factory
    address internal _creditLineFactory;

    /// @notice The address of the liquidity pool factory
    address internal _liquidityPoolFactory;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain
    uint256[47] private __gap;
}

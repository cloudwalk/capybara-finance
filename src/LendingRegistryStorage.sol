// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title LendingRegistryStorage contract
/// @notice Defines the storage layout for the LendingRegistry contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
abstract contract LendingRegistryStorage {
    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice The address of the credit line factory
    address internal _creditLineFactory;

    /// @notice The address of the liquidity pool factory
    address internal _liquidityPoolFactory;

    /// @notice The address of the associated lending market
    address internal _market;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain
    uint256[47] private __gap;
}

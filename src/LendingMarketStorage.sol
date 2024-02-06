// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Loan} from "./libraries/Loan.sol";

/// @title LendingMarketStorage contract
/// @notice Defines the storage layout for the lending market contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
abstract contract LendingMarketStorage {
    /************************************************
     *  Storage variables
     ***********************************************/

    /// @notice The counter of the NFT token identifiers
    uint256 internal _tokenIdCounter;

    /// @notice The address of the lending registry
    address internal _registry;

    /// @notice The mapping of loan identifier to loan state
    mapping(uint256 => Loan.State) internal _loans;

    /// @notice The mapping of credit line to associated lender
    mapping(address => address) internal _creditLines;

    /// @notice The mapping of lender to associated liquidity pool
    mapping(address => address) internal _liquidityPools;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain
    uint256[45] private __gap;
}
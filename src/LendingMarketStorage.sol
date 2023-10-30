// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Loan} from "./libraries/Loan.sol";

/// @title LendingMarketStorage contract
/// @notice Defines the storage layout for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
abstract contract LendingMarketStorage {
    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice The address of the NFT token
    address internal _nft;

    /// @notice The address of the lending registry
    address internal _registry;

    /// @notice The mapping of credit line to associated lender
    mapping(address => address) internal _creditLines;

    /// @notice The mapping of lender to associated liquidity pool
    mapping(address => address) internal _liquidityPools;

    /// @notice The mapping of loan identifier to stored loan state
    mapping(uint256 => Loan.State) internal _loans;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title CapybaraNFTStorage contract
/// @notice Defines the storage layout for the CapybaraNFT contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
abstract contract CapybaraNFTStorage {
    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice The counter of the NFT token unique identifiers
    uint256 internal _tokenIdCounter;

    /// @notice Rhe address of the associated lending market
    address internal _market;
}

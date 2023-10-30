// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title ICapybaraNFT interface
/// @notice Defines the Capybara NFT token functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ICapybaraNFT {
    /************************************************
     *  FUNCTIONS
     ***********************************************/

    /// @notice Mints a new NFT token and transfers it to the receiver
    /// @dev This function is only callable by the lending market
    /// @param to The address of the token owner and receiver
    /// @return The unique identifier of the minted token
    function safeMint(address to) external returns (uint256);

    /// @notice Returns the address of the associated lending market
    function market() external view returns (address);
}

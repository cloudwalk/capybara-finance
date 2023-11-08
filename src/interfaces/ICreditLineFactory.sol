// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title ICreditLineFactory interface
/// @notice Defines the credit line factory functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ICreditLineFactory {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when a new credit line is created
    /// @param market The address of the associated lending market
    /// @param lender The address of the lender
    /// @param kind The kind of the created credit line
    /// @param creditLine The address of the created credit line
    event CreditLineCreated(address indexed market, address indexed lender, uint16 indexed kind, address creditLine);

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Creates a new credit line
    /// @param market The address of the lending market
    /// @param lender The address of the lender
    /// @param kind The kind of credit line to create
    /// @param data The data to configure the credit line
    /// @return The address of the created credit line contract
    function createCreditLine(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address);

    /// @notice Returns the list of supported credit line kinds
    function supportedKinds() external view returns (uint16[] memory);
}

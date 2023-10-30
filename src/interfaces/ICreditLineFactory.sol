// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @title ICreditLineFactory interface
/// @notice Defines the credit line factory functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ICreditLineFactory {
    /************************************************
     *  EVENTS
     ***********************************************/

    /// @notice Emitted when a new credit line is created
    /// @param market The address of the associated lending market
    /// @param kind The kind of credit line
    /// @param creditLine The address of the created credit line contract
    event CreditLineCreated(address indexed market, uint16 indexed kind, address creditLine);

    /************************************************
     *  FUNCTIONS
     ***********************************************/

    /// @notice Creates a new credit line
    /// @param market The address of the market
    /// @param lender The address of the lender
    /// @param kind The kind of credit line to create
    /// @param data The data to configure the credit line
    /// @return The address of the created credit line contract
    function createCreditLine(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title ICreditLineFactory interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the credit line factory contract functions and events.
interface ICreditLineFactory {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @dev Emitted when a new credit line is created.
    /// @param market The address of the lending market.
    /// @param lender The address of the credit line lender.
    /// @param token The address of the credit line token.
    /// @param kind The kind of the created credit line.
    /// @param creditLine The address of the created credit line.
    event CreditLineCreated(
        address indexed market, address indexed lender, address indexed token, uint16 kind, address creditLine
    );

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Creates a new credit line.
    /// @param market The address of the lending market.
    /// @param lender The address of the credit line lender.
    /// @param token The address of the credit line token.
    /// @param kind The kind of credit line to create.
    /// @param data The data to configure the credit line.
    /// @return The address of the created credit line.
    function createCreditLine(
        address market,
        address lender,
        address token,
        uint16 kind,
        bytes calldata data
    ) external returns (address);

    /// @dev Returns the list of supported credit line kinds.
    function supportedKinds() external view returns (uint16[] memory);
}

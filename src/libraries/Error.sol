// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title Error library
/// @notice Defines common error types
/// @author CloudWalk Inc. (See https://cloudwalk.io)
library Error {
    /// @notice Thrown when the caller is not authorized
    error Unauthorized();

    /// @notice Thrown when the specified address is zero
    error ZeroAddress();

    /// @notice Thrown when the specified amount is invalid
    error InvalidAmount();

    /// @notice Thrown when the configuration is already applied
    error AlreadyConfigured();

    /// @notice Thrown when the called function is not implemented
    error NotImplemented();
}

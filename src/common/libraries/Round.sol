// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Round library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines upward and downward rounding functions.
library Round {
    /// @dev Rounds up a value to the nearest multiple of a precision.
    /// @param value The value to be rounded.
    /// @param precision The precision to round to.
    function roundUp(uint256 value, uint256 precision) internal pure returns (uint256) {
        return (value + precision - 1) / precision * precision;
    }

    /// @dev Rounds down a value to the nearest multiple of a precision.
    /// @param value The value to be rounded.
    /// @param precision The precision to round to.
    function roundDown(uint256 value, uint256 precision) internal pure returns (uint256) {
        return value / precision * precision;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Round library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines upward and downward rounding functions.
library Round {
    /// @dev Rounds up a value to the nearest multiple of an accuracy.
    /// @param value The value to be rounded.
    /// @param accuracy The accuracy to which the value should be rounded.
    function roundUp(uint256 value, uint256 accuracy) internal pure returns (uint256) {
        return ((value + accuracy - 1) / accuracy) * accuracy;
    }

    /// @dev Rounds down a value to the nearest multiple of an accuracy.
    /// @param value The value to be rounded.
    /// @param accuracy The accuracy to which the value should be rounded.
    function roundDown(uint256 value, uint256 accuracy) internal pure returns (uint256) {
        return (value / accuracy) * accuracy;
    }
}

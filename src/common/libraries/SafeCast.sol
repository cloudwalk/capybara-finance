// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// @title SafeCast library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines safe casting functions from uint256 to other sizes.
library SafeCast {
    /// @dev Value doesn't fit in an uint of `bits` size.
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /// @dev Returns the downcasted uint128 from uint256, reverting on
    /// overflow (when the input is greater than largest uint128).
    ///
    /// Counterpart to Solidity's `uint128` operator.
    ///
    /// Requirements:
    ///
    /// - input must fit into 128 bits
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /// @dev Returns the downcasted uint64 from uint256, reverting on
    /// overflow (when the input is greater than largest uint64).
    ///
    /// Counterpart to Solidity's `uint64` operator.
    ///
    /// Requirements:
    ///
    /// - input must fit into 64 bits
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /// @dev Returns the downcasted uint32 from uint256, reverting on
    /// overflow (when the input is greater than largest uint32).
    ///
    /// Counterpart to Solidity's `uint32` operator.
    ///
    /// Requirements:
    ///
    /// - input must fit into 32 bits
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }
}

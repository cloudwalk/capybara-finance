// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Constants library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the constants used across the contracts.
library Constants {
    uint256 public constant PERIOD_IN_SECONDS = 24 hours;

    uint256 public constant NEGATIVE_TIME_SHIFT = 3 hours;

    uint256 public constant INTEREST_RATE_FACTOR = 10 ** 9;
}
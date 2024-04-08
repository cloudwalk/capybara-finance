// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Interest library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the common types used for interest calculation.
library Interest {
    /// @dev An enum that defines the available interest formulas.
    ///
    /// The possible values:
    ///
    /// - Simple --- Simple interest rate is linear and is only calculated on the initial principal amount.
    /// - Compound - Compound interest rate is calculated by including interests of previous periods.
    enum Formula {
        Simple,  // 0
        Compound // 1
    }
}

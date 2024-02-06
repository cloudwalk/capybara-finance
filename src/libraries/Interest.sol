// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title Interest library
/// @notice Defines interest calculation types
/// @author CloudWalk Inc. (See https://cloudwalk.io)
library Interest {
    /// @notice An enum that defines the available interest formulas
    ///
    /// The possible values:
    /// - Simple --- Simple interest rate is linear and is only calculated on the initial principal amount
    /// - Compound - Compound interest rate is calculated on the initial principal, which includes each of the reinvested interests
    enum Formula {
        Simple, //-- 0
        Compound //- 1
    }
}

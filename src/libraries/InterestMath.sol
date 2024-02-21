// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Interest} from "./Interest.sol";

/// @title InterestMath library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines interest calculation functions
library InterestMath {
    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the specified interest formula is not implemented
    error InterestFormulaNotImplemented();

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @notice Calculates the outstanding balance of a loan
    /// @param originalBalance The original balance of the loan
    /// @param numberOfPeriods The number of periods since the loan was taken
    /// @param interestRate The interest rate applied to the loan
    /// @param interestRateFactor The interest rate factor
    /// @param interestFormula The interest formula
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) internal pure returns (uint256 remainingBalance) {
        if (interestFormula == Interest.Formula.Compound) {
            uint256 outstandingBalance = originalBalance;
            for (uint256 i = 0; i < numberOfPeriods; i++) {
                outstandingBalance += outstandingBalance * interestRate / interestRateFactor;
            }
            return outstandingBalance;
        } else {
            revert InterestFormulaNotImplemented();
        }
    }
}

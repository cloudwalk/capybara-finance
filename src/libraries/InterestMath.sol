// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Interest } from "./Interest.sol";

/// @title InterestMath library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the common functions used for interest calculation.
library InterestMath {
    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the specified interest formula is not implemented.
    error InterestFormulaNotImplemented();

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan.
    /// @param originalBalance The balance of the loan at the beginning.
    /// @param numberOfPeriods The number of periods to calculate the outstanding balance.
    /// @param interestRate The interest rate to use for the calculation (see interestRateFactor).
    /// @param interestRateFactor The interest rate factor used with the interest rate.
    /// @param interestFormula The interest formula to use for the calculation.
    /// @return The outstanding balance of the loan.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) internal pure returns (uint256) {
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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Interest } from "./Interest.sol";

/// @title InterestMath library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines interest calculation functions.
library InterestMath {
    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @dev Thrown when the specified interest formula is not implemented.
    error InterestFormulaNotImplemented();

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan.
    /// @param originalBalance The original balance of the loan.
    /// @param numberOfPeriods The number of periods since the loan was taken.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    /// @param interestFormula The interest formula.
    /// @return The outstanding balance of the loan.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) internal pure returns (uint256) {
        if (interestFormula == Interest.Formula.Compound) {
            return _calculateOutstandingBalanceInLoop(
                originalBalance,
                numberOfPeriods,
                interestRate,
                interestRateFactor);
        } else {
            revert InterestFormulaNotImplemented();
        }
    }

    /// @dev Calculates the outstanding balance of a loan using a loop.
    /// @param originalBalance The original balance of the loan.
    /// @param numberOfPeriods The number of periods since the loan was taken.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    /// @return outstandingBalance The outstanding balance of the loan.
    function _calculateOutstandingBalanceInLoop(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256 outstandingBalance) {
        outstandingBalance = originalBalance;
        for (uint256 i = 0; i < numberOfPeriods; i++) {
            outstandingBalance += (outstandingBalance * interestRate) / interestRateFactor;
        }
    }
}

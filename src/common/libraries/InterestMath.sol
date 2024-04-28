// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Interest } from "./Interest.sol";
import { ABDKMath64x64 } from "./ABDKMath64x64.sol";

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
            return _calculateOutstandingBalance(originalBalance, numberOfPeriods, interestRate, interestRateFactor);
        } else {
            revert InterestFormulaNotImplemented();
        }
    }

    /// @dev Calculates the outstanding balance of a loan using the compound interest formula.
    /// @param originalBalance The original balance of the loan.
    /// @param numberOfPeriods The number of periods since the loan was taken.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    /// @return outstandingBalance The outstanding balance of the loan.
    function _calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256 outstandingBalance) {
        // The equivalent formula: round(originalBalance * (1 + interestRate / interestRateFactor)^numberOfPeriods)
        // Where division operator `/` and power operator `^` take into account the fractional part and
        // the `round()` function returns an integer rounded according to standard mathematical rules.
        int128 onePlusRateValue = ABDKMath64x64.divu(interestRateFactor + interestRate, interestRateFactor);
        int128 powValue = ABDKMath64x64.pow(onePlusRateValue, numberOfPeriods);
        uint256 unroundedResult = uint256(uint128(ABDKMath64x64.mul(powValue, int128(int256(originalBalance << 64)))));
        outstandingBalance = unroundedResult >> 64;
        if ((unroundedResult - (outstandingBalance << 64)) >= (1 << 63)) {
            outstandingBalance += 1;
        }
        return outstandingBalance;
    }

    /// @dev Calculates the outstanding balance of a loan using a loop and the compound interest formula.
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

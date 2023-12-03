// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Interest} from "./Interest.sol";

/// @title InterestMath library
/// @notice Defines interest calculation functions
/// @author CloudWalk Inc. (See https://cloudwalk.io)
library InterestMath {
    /************************************************
     *  Constants
     ***********************************************/

    /// @notice The maximum compouning step used when calculating the outstanding balance
    uint256 constant MAX_COMPOUND_STEP = 10;

    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the specified interest formula is not implemented
    error InterestFormulaNotImplemented();

    /************************************************
     *  Public functions
     ***********************************************/

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
            remainingBalance =
                _calculateOutstandingBalance(originalBalance, numberOfPeriods, interestRate, interestRateFactor);
        } else {
            revert InterestFormulaNotImplemented();
        }
    }

    /************************************************
     *  Private functions
     ***********************************************/

    /// @notice Calculates the outstanding balance using the compound interest formula
    function _calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256) {
        if (numberOfPeriods > MAX_COMPOUND_STEP) {
            uint256 remainingBalance =
                _compoundOutstandingBalance(originalBalance, MAX_COMPOUND_STEP, interestRate, interestRateFactor);
            return _calculateOutstandingBalance(
                remainingBalance, numberOfPeriods - MAX_COMPOUND_STEP, interestRate, interestRateFactor
            );
        } else {
            return _compoundOutstandingBalance(originalBalance, numberOfPeriods, interestRate, interestRateFactor);
        }
    }

    /// @notice Executes one step of the compound interest formula calculation
    function _compoundOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) private pure returns (uint256) {
        return (originalBalance * (interestRateFactor + interestRate) ** numberOfPeriods)
            / interestRateFactor ** numberOfPeriods;
    }
}

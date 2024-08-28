// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { InterestMath } from "src/common/libraries/InterestMath.sol";

/// @title LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the lending market contract.
contract OutstandingBalance_v2
{
    /// @dev Calculates the outstanding balance of a loan.
    /// @param originalBalance The balance of the loan at the beginning.
    /// @param numberOfPeriods The number of periods to calculate the outstanding balance.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) external pure returns (uint256) {
        return
            InterestMath.calculateOutstandingBalance(
                originalBalance,
                numberOfPeriods,
                interestRate,
                interestRateFactor
            );
    }

    function calculateOutstandingBalance2(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) external view returns (uint256) {
        return
            InterestMath.calculateOutstandingBalance2(
            originalBalance,
            numberOfPeriods,
            interestRate,
            interestRateFactor
        );
    }

    function calculateOutstandingBalance3(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) external view returns (uint256) {
        return
            InterestMath.calculateOutstandingBalance3(
            originalBalance,
            numberOfPeriods,
            interestRate,
            interestRateFactor
        );
    }
}

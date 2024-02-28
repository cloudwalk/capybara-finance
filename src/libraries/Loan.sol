// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Interest } from "./Interest.sol";

/// @title Loan library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the common types used for loan management.
library Loan {
    /// @notice A struct that defines the state of the loan.
    struct State {
        // Slot 1
        address token;                    // The address of the token used in the loan.
        uint32 interestRatePrimary;       // The primary interest rate that is applied to the loan.
        uint32 interestRateSecondary;     // The secondary interest rate that is applied to the loan.
        uint32 interestRateFactor;        // The rate factor used together with interest rate.
        // Slot 2
        address borrower;                 // The address of the borrower.
        uint32 startDate;                 // The start date of the loan.
        uint64 initialBorrowAmount;       // The initial principal amount of the loan.
        // Slot 3
        uint32 periodInSeconds;           // The duration of the loan period specified in seconds.
        uint32 durationInPeriods;         // The total duration of the loan determined by the number of periods.
        uint64 trackedBorrowAmount;       // The updated loan amount after the last repayment.
        uint32 trackedDate;               // The date of the last repayment.
        uint32 freezeDate;                // The date when the loan was frozen.
        bool autoRepayment;               // The flag that indicates whether the loan can be repaid automatically.
        Interest.Formula interestFormula; // The formula used for interest calculation on the loan.
        // Slot 4
        address holder;                   // The address of the loan holder.
    }

    /// @notice A struct that defines the terms of the loan.
    struct Terms {
        // Slot 1
        address token;                    // The address of the token to be used in the loan.
        uint32 periodInSeconds;           // The duration of the loan period specified in seconds.
        uint32 durationInPeriods;         // The total duration of the loan determined by the number of periods.
        uint32 interestRateFactor;        // The rate factor used together with interest rate.
        // Slot 2
        address addonRecipient;           // The address of the recipient of addon payments and fees.
        uint64 addonAmount;               // The amount of addon payments and fees.
        uint32 interestRatePrimary;       // The primary interest rate to be applied to the loan.
        // Slot 3
        uint32 interestRateSecondary;     // The secondary interest rate to be applied to the loan.
        bool autoRepayment;               // The flag that indicates whether the loan can be repaid automatically.
        Interest.Formula interestFormula; // The formula to be used for interest calculation on the loan.
        // Slot 4
        address holder;                   // The address of the loan holder.
    }

    /// @notice A struct that defines the preview of the loan
    struct Preview {
        uint256 periodDate;         // The period date that the loan is previewed for
        uint256 outstandingBalance; // The outstanding balance of the loan at previewed period
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Loan library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the common types used for loan management.
library Loan {
    /// @dev A struct that defines the stored state of a loan.
    struct State {
        // Slot 1
        address borrower;             // The address of the borrower.
        uint64 loanAmount;            // The initial amount of the loan, excluding the addon.
        uint32 startTimestamp;        // The timestamp when the loan was created (stated).
        // Slot 2
        uint64 repaidAmount;          // The amount that has been repaid on the loan over its lifetime.
        uint64 trackedBalance;        // The balance of the loan that is tracked over its lifetime.
        uint32 trackedTimestamp;      // The timestamp when the loan was last paid or its balance was updated.
        uint32 freezeTimestamp;       // The timestamp when the loan was frozen. Zero value for unfrozen loans.
        uint32 durationInPeriods;     // The total duration of the loan determined by the number of periods.
        // uint32 __reserved;         // Reserved for future use.
        // Slot 3
        uint64 addonAmount;           // The amount of the loan     addon (extra charges or fees).
        uint32 interestRatePrimary;   // The primary interest rate that is applied to the loan.
        uint32 interestRateSecondary; // The secondary interest rate that is applied to the loan.
    }

    /// @dev A struct that defines the terms of the loan.
    struct Terms {
        address borrower;              // The borrower.
        uint256 loanAmount;            // The loan amount.
        uint256 addonAmount;           // The amount of the loan addon (extra charges or fees).
        uint256 durationInPeriods;     // The total duration of the loan determined by the number of periods.
        uint256 interestRatePrimary;   // The primary interest rate to be applied to the loan.
        uint256 interestRateSecondary; // The secondary interest rate to be applied to the loan.
    }

    /// @dev A struct that defines the preview of the loan.
    struct Preview {
        uint256 periodIndex;        // The period index that matches the preview timestamp.
        uint256 trackedBalance;     // The tracked balance of the loan at the previewed period.
        uint256 outstandingBalance; // The outstanding balance of the loan at the previewed period.
    }
}

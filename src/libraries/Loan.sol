// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Interest} from "./Interest.sol";

/// @title Loan library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines loan related types
library Loan {
    /// @notice An enum that defines the possible loan statuses
    ///
    /// The possible values:
    /// - Nonexistent - Indicates that the loan does not exist
    /// - Active ------ Indicates that the loan exists and is active
    /// - Repaid ------ Indicates that the loan has been fully repaid
    /// - Frozen ------ Indicates that the loan has been temporarily frozen
    /// - Defaulted --- Indicates that the borrower has defaulted on the loan
    /// - Recovered --- Indicates that the loan has been recovered after default
    enum Status {
        Nonexistent, //- 0
        Active, //------ 1
        Repaid, //------ 2
        Frozen, //------ 3
        Defaulted, //--- 4
        Recovered //---- 5
    }

    /// @notice A struct that defines the terms of the loan
    struct Terms {
        //slot 1
        /// @notice The address of the token to be used in the loan
        address token;
        /// @notice The duration of the loan period specified in seconds
        uint32 periodInSeconds;
        /// @notice The total duration of the loan determined by the number of periods
        uint32 durationInPeriods;
        /// @notice The rate factor used together with interest rate
        uint32 interestRateFactor;

        //slot 2
        /// @notice The address of the recipient of additional payments and fees
        address addonRecipient;
        /// @notice The amount of additional payments and fees
        uint64 addonAmount;
        /// @notice The primary interest rate to be applied to the loan
        uint32 interestRatePrimary;

        //slot 3
        /// @notice The secondary interest rate to be applied to the loan
        uint32 interestRateSecondary;
        /// @notice Whether the loan can be repaid automatically
        bool autoRepayment;
        /// @notice The formula to be used for interest calculation on the loan
        Interest.Formula interestFormula;
    }

    /// @notice A struct that defines the stored state of the loan
    struct State {
        //slot 1
        /// @notice The address of the token used in the loan
        address token;
        /// @notice The primary interest rate that is applied to the loan
        uint32 interestRatePrimary;
        /// @notice The secondary interest rate that is applied to the loan
        uint32 interestRateSecondary;
        /// @notice The rate factor used together with interest rate
        uint32 interestRateFactor;

        //slot 2
        /// @notice The address of the borrower
        address borrower;
        /// @notice The start date of the loan
        uint32 startDate;
        /// @notice The initial principal amount of the loan
        uint64 initialBorrowAmount;

        //slot 3
        /// @notice The duration of the loan period specified in seconds
        uint32 periodInSeconds;
        /// @notice The total duration of the loan determined by the number of periods
        uint32 durationInPeriods;
        /// @notice The updated loan amount after the last repayment
        uint64 trackedBorrowAmount;
        /// @notice The date of the last repayment
        uint32 trackDate;
        /// @notice The date when the loan was frozen
        uint32 freezeDate;
        /// @notice Whether the loan can be repaid automatically
        bool autoRepayment;
        /// @notice The formula used for interest calculation on the loan
        Interest.Formula interestFormula;
    }
}

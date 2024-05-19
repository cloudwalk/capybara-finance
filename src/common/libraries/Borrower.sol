// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Loan library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the common types used for loan management.
library Borrower {
    /// @dev An enum that defines the available policies to work with the borrower allowance.
    ///
    /// The possible values:
    ///
    /// - Reset ---- Reset the borrower allowance after the first loan taken, the default behaviour.
    /// - Keep ----- Do not change anything about the borrower allowance.
    /// - Decrease - Decrease the borrower allowance after each loan taken and do not restore it
    /// - Iterate -- Decrease the borrower allowance after each loan taken and restore it after loan finishing
    enum AllowancePolicy {
        Reset,    // 0
        Keep,     // 1
        Decrease, // 2
        Iterate   // 3
    }

    /// @dev TODO
    struct Config {
        // Slot 1
        uint64 minLoanAmount;            // The minimum amount of tokens the borrower can take as a loan.
        uint64 maxLoanAmount;            // The maximum amount of tokens the borrower can take as a loan.
        uint32 expiration;               // The expiration date of the configuration.
        uint16 maxActiveLoanCounter;     // TODO
        AllowancePolicy allowancePolicy; // The borrower allowance policy to be applied to the borrower.
        // uint40 __reserved;            // Reserved for future use.
    }

    /// @dev TODO
    struct State {
        uint64 allowance; // TODO
        uint16 activeLoanCounter; // TODO
        uint16 totalLoanCounter; // TODO
    }
}

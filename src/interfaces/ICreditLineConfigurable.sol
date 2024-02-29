// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Interest } from "../libraries/Interest.sol";

/// @title ICreditLineConfigurable interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the configurable credit line contract functions and events.
interface ICreditLineConfigurable {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @notice Emitted when admin is configured.
    /// @param admin The address of the admin account.
    /// @param adminStatus True if the account is an admin.
    event ConfigureAdmin(address indexed admin, bool adminStatus);

    /// @notice Emitted when the credit line is configured.
    /// @param creditLine The address of the current credit line.
    /// @param config The struct containing the credit line configuration.
    event ConfigureCreditLine(address indexed creditLine, CreditLineConfig config);

    /// @notice Emitted when the borrower is configured.
    /// @param creditLine The address of the current credit line.
    /// @param borrower The address of the borrower being configured.
    /// @param config The struct containing the borrower configuration.
    event ConfigureBorrower(address indexed creditLine, address indexed borrower, BorrowerConfig config);

    // -------------------------------------------- //
    //  Structs and enums                           //
    // -------------------------------------------- //

    /// @notice An enum that defines the available borrow policies.
    /// The possible values:
    /// - Reset ---- Reset borrow allowance after the first loan taken.
    /// - Decrease - Decrease borrow allowance after each loan taken.
    /// - Keep ----- Do not change anything about borrow allowance.
    enum BorrowPolicy {
        Reset,    // 0
        Decrease, // 1
        Keep      // 2
    }

    /// @notice A struct that defines credit line configuration.
    struct CreditLineConfig {
        // Slot 1
        address holder;                  // The address of the loan holder.
        uint32 periodInSeconds;          // The duration of the loan period determined in seconds.
        uint32 minDurationInPeriods;     // The minimum duration of the loan determined in periods.
        uint32 maxDurationInPeriods;     // The maximum duration of the loan determined in periods.
        // Slot 2
        uint64 minBorrowAmount;          // The minimum amount of tokens the borrower can take as a loan.
        uint64 maxBorrowAmount;          // The maximum amount of tokens the borrower can take as a loan.
        uint32 minInterestRatePrimary;   // The minimum primary interest rate to be applied to the loan.
        uint32 maxInterestRatePrimary;   // The maximum primary interest rate to be applied to the loan.
        uint32 minInterestRateSecondary; // The minimum secondary interest rate to be applied to the loan.
        uint32 maxInterestRateSecondary; // The maximum secondary interest rate to be applied to the loan.
        // Slot 3
        uint32 interestRateFactor;       // The interest rate factor used for interest calculation.
        address addonRecipient;          // The address of addon payments recipient.
    }

    /// @notice A struct that defines borrower configuration.
    struct BorrowerConfig {
        // Slot 1
        uint32 expiration;                // The expiration date of the configuration.
        uint32 durationInPeriods;         // The initial loan duration determined in periods.
        uint32 interestRatePrimary;       // The primary interest rate to be applied to the loan.
        uint32 interestRateSecondary;     // The secondary interest rate to be applied to the loan.
        uint64 minBorrowAmount;           // The minimum amount of tokens the borrower can take as a loan.
        uint64 maxBorrowAmount;           // The maximum amount of tokens the borrower can take as a loan.
        // Slot 2
        uint32 addonFixedCostRate;        // The fixed cost rate to be used for addon payment calculation.
        uint32 addonPeriodCostRate;       // The period cost rate to be used for addon payment calculation.
        Interest.Formula interestFormula; // The formula to be used for interest calculation on the loan.
        BorrowPolicy borrowPolicy;        // The borrow policy to be applied to the borrower.
        bool autoRepayment;               // Whether the loan can be repaid automatically.
    }

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @notice Configures an admin status.
    /// @param admin The address of the admin to configure.
    /// @param adminStatus True whether the account is an admin.
    function configureAdmin(address admin, bool adminStatus) external;

    /// @notice Updates the credit line configuration.
    /// @param config The struct containing the credit line configuration.
    function configureCreditLine(CreditLineConfig memory config) external;

    /// @notice Configures a specific borrower.
    /// @param borrower The address of the borrower to configure.
    /// @param config The struct containing the borrower configuration.
    function configureBorrower(address borrower, BorrowerConfig memory config) external;

    /// @notice Configures multiple borrowers at once.
    /// @param borrowers The addresses of the borrowers to configure.
    /// @param configs The structs containing the borrower configurations.
    function configureBorrowers(address[] memory borrowers, BorrowerConfig[] memory configs) external;

    /// @notice Retrieves the borrower configuration.
    /// @param borrower The address of the borrower to check.
    /// @return The struct containing the borrower configuration.
    function getBorrowerConfiguration(address borrower) external view returns (BorrowerConfig memory);

    /// @notice Retrieves the credit line configuration.
    /// @return The struct containing the credit line configuration.
    function creditLineConfiguration() external view returns (CreditLineConfig memory);

    /// @notice Checks whether the account is an admin.
    /// @param account The address of the account to check.
    /// @return True if the account is configured as an admin.
    function isAdmin(address account) external view returns (bool);
}

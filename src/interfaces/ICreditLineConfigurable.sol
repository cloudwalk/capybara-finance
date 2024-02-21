// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Interest} from "../libraries/Interest.sol";

/// @title ICreditLineConfigurable interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the configurable credit line contract functions and events
interface ICreditLineConfigurable {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when admin is configured
    /// @param admin The address of the admin account
    /// @param adminStatus True if the account is an admin
    event ConfigureAdmin(address indexed admin, bool adminStatus);

    /// @notice Emitted when the credit line is configured
    /// @param creditLine The address of the credit line
    /// @param config The credit line configuration
    event ConfigureCreditLine(address indexed creditLine, CreditLineConfig config);

    /// @notice Emitted when the borrower is configured
    /// @param creditLine The address of the credit line
    /// @param borrower The address of the borrower
    /// @param config The borrower configuration
    event ConfigureBorrower(address indexed creditLine, address indexed borrower, BorrowerConfig config);

    /************************************************
     *  Structs and Enums
     ***********************************************/

    /// @notice An enum that defines the borrow policy
    ///
    /// The possible values:
    /// - Reset ---- Reset borrow allowance after the first loan taken
    /// - Decrease - Decrease borrow allowance after each loan taken
    /// - Keep ---- Do not change anything about borrow allowance
    enum BorrowPolicy {
        Reset, //---- 0
        Decrease, //- 1
        Keep //------ 2
    }

    /// @notice A struct that defines credit line configuration
    struct CreditLineConfig {
        //slot 1
        /// @notice The duration of the loan period determined in seconds
        uint32 periodInSeconds;
        /// @notice The interest rate factor used for interest calculation
        uint32 interestRateFactor;
        /// @notice The minimum primary interest rate to be applied to the loan
        uint32 minInterestRatePrimary;
        /// @notice The maximum primary interest rate to be applied to the loan
        uint32 maxInterestRatePrimary;
        /// @notice The minimum secondary interest rate to be applied to the loan
        uint32 minInterestRateSecondary;
        /// @notice The maximum secondary interest rate to be applied to the loan
        uint32 maxInterestRateSecondary;
        /// @notice The period cost rate to be used for additional payment calculation
        uint32 addonPeriodCostRate;
        /// @notice The fixed cost rate to be used for additional payment calculation
        uint32 addonFixedCostRate;

        //slot 2
        /// @notice The minimum duration of the loan determined in periods
        uint32 minDurationInPeriods;
        /// @notice The maximum duration of the loan determined in periods
        uint32 maxDurationInPeriods;
        /// @notice The minimum amount the borrower can take as a loan
        uint64 minBorrowAmount;
        /// @notice The maximum amount the borrower can take as a loan
        uint64 maxBorrowAmount;
    }

    /// @notice A struct that defines borrower configuration
    struct BorrowerConfig {
        //slot 1
        /// @notice The total duration of the loan determined in periods
        uint32 durationInPeriods;
        /// @notice The primary interest rate to be applied to the loan
        uint32 interestRatePrimary;
        /// @notice The secondary interest rate to be applied to the loan
        uint32 interestRateSecondary;
        /// @notice The address of the recipient of additional payments and fees
        address addonRecipient;

        //slot 2
        /// @notice The expiration date of the borrower configuration
        uint32 expiration;
        /// @notice The minimum amount the borrower can take as a loan
        uint64 minBorrowAmount;
        /// @notice The maximum amount the borrower can take as a loan
        uint64 maxBorrowAmount;
        /// @notice The formula to be used for interest calculation on the loan
        Interest.Formula interestFormula;
        /// @notice The borrow policy to be applied to the borrower
        BorrowPolicy borrowPolicy;
        /// @notice Whether the loan can be repaid automatically
        bool autoRepayment;
    }

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Configures an admin status
    /// @param admin The address of the admin to configure
    /// @param adminStatus True whether the account is an admin
    function configureAdmin(address admin, bool adminStatus) external;

    /// @notice Updates the credit line configuration
    /// @param config The struct containing the credit line configuration
    function configureCreditLine(CreditLineConfig memory config) external;

    /// @notice Configures a specific borrower
    /// @param borrower The address of the borrower to configure
    /// @param config The struct containing the borrower configuration
    function configureBorrower(address borrower, BorrowerConfig memory config) external;

    /// @notice Configures multiple borrowers at once
    /// @param borrowers The addresses of the borrowers to configure
    /// @param configs The structs containing the borrower configurations
    function configureBorrowers(address[] memory borrowers, BorrowerConfig[] memory configs) external;

    /// @notice Retrieves the configuration of a borrower
    /// @param borrower The address of the borrower to check
    /// @return The struct containing the borrower configuration
    function getBorrowerConfiguration(address borrower) external view returns (BorrowerConfig memory);

    /// @notice Retrieves the configuration of the credit line
    /// @return The struct containing the credit line configuration
    function creditLineConfiguration() external view returns (CreditLineConfig memory);

    /// @notice Checks whether an account is an admin
    /// @param account The address of the account to check
    /// @return True if the account is configured as an admin
    function isAdmin(address account) external view returns (bool);
}

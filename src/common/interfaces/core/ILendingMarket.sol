// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Borrower } from "../../libraries/Borrower.sol";
import { Loan } from "../../libraries/Loan.sol";

/// @title ILendingMarket interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the lending market contract functions and events.
interface ILendingMarket {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @dev Emitted when a loan is taken.
    /// @param loanId The unique identifier of the loan.
    /// @param borrower The address of the borrower of the loan.
    /// @param loanAmount The initial total amount of the loan, including the addon.
    /// @param durationInPeriods The duration of the loan in periods.
    /// @param addonAmount TODO
    /// @param interestRatePrimary TODO
    /// @param interestRateSecondary TODO
    /// @param initiator TODO
    event LoanTaken(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 loanAmount,
        uint256 durationInPeriods,
        uint256 addonAmount,
        uint256 interestRatePrimary,
        uint256 interestRateSecondary,
        address initiator
    );

    /// @dev Emitted when a loan is repaid (fully or partially).
    /// @param loanId The unique identifier of the loan.
    /// @param borrower The address of the borrower of the loan.
    /// @param source TODO.
    /// @param amount The amount of the repayment.
    /// @param outstandingBalance The outstanding balance of the loan after the repayment.
    /// @param initiator TODO
    event LoanRepayment(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed source,
        uint256 amount,
        uint256 outstandingBalance,
        address initiator
    );

    /// @dev Emitted when a loan is frozen.
    /// @param loanId The unique identifier of the loan.
    event LoanFrozen(uint256 indexed loanId);

    /// @dev Emitted when a loan is unfrozen.
    /// @param loanId The unique identifier of the loan.
    event LoanUnfrozen(uint256 indexed loanId);

    /// @dev Emitted when a loan is revoked.
    /// @param loanId The unique identifier of the loan.
    event LoanRevoked(uint256 indexed loanId, address initiator);

    /// @dev Emitted when the duration of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newDuration The new duration of the loan in periods.
    /// @param oldDuration The old duration of the loan in periods.
    event LoanDurationUpdated(
        uint256 indexed loanId,
        uint256 indexed newDuration,
        uint256 indexed oldDuration
    );

    /// @dev Emitted when the primary interest rate of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newInterestRate The new primary interest rate of the loan.
    /// @param oldInterestRate The old primary interest rate of the loan.
    event LoanInterestRatePrimaryUpdated(
        uint256 indexed loanId,
        uint256 indexed newInterestRate,
        uint256 indexed oldInterestRate
    );

    /// @dev Emitted when the secondary interest rate of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newInterestRate The new secondary interest rate of the loan.
    /// @param oldInterestRate The old secondary interest rate of the loan.
    event LoanInterestRateSecondaryUpdated(
        uint256 indexed loanId,
        uint256 indexed newInterestRate,
        uint256 indexed oldInterestRate
    );

    /// @dev TODO
    event BorrowerConfigCreated(
        bytes32 configId
    );

    /// @dev TODO
    event BorrowerConfigAssigned(
        address indexed borrower,
        bytes32 newConfigId,
        bytes32 oldConfigId
    );

    /// @dev Emitted when tokens are deposited to the market pool for loans.
    /// @param amount The amount of tokens deposited to the market pool.
    event Deposit(uint256 amount);

    /// @dev Emitted when tokens are withdrawn from the market.
    /// @param poolAmount The amount of tokens withdrawn from the pool balance.
    /// @param addonAmount The amount of tokens withdrawn from the addons balance.
    event Withdrawal(uint256 poolAmount, uint256 addonAmount);

    /// @dev Emitted when tokens are rescued from the liquidity pool.
    /// @param token The address of the token rescued.
    /// @param amount The amount of tokens rescued.
    event Rescue(address indexed token, uint256 amount);

    /// @dev TODO
    event BorrowerAllowanceUpdated(
        address indexed borrower,
        uint256 newAllowance,
        uint256 oldAllowance
    );

    // -------------------------------------------- //
    //  Admin functions                             //
    // -------------------------------------------- //

    /// @dev TODO
    function createBorrowerConfig(
        bytes32 configId,
        Borrower.Config calldata newConfig
    ) external;

    /// @dev TODO
    function assignConfigToBorrowers(
        bytes32 newConfigId,
        address[] calldata borrowers
    ) external;

    /// @dev Deposits tokens to the market pool for loans.
    /// @param amount The amount of tokens to deposit.
    function deposit(uint256 amount) external;

    /// @dev Withdraws tokens from the market.
    /// @param poolAmount The amount of tokens to withdraw from the pool balance.
    /// @param addonAmount The amount of tokens to withdraw from the addons balance.
    function withdraw(uint256 poolAmount, uint256 addonAmount) external;

    /// @dev Rescues tokens from the market.
    /// @param token_ The address of the token to rescue.
    /// @param amount The amount of tokens to rescue.
    function rescue(address token_, uint256 amount) external;

    /// @dev TODO
    function changeBorrowerAllowance(address borrower, int256 changeAmount) external;

    // -------------------------------------------- //
    //  Manager functions                           //
    // -------------------------------------------- //

    /// @dev Takes a loan.
    /// @param borrower TODO
    /// @param loanAmount The desired amount of tokens to borrow.
    /// @param addonAmount TODO
    /// @param durationInPeriods TODO
    /// @param interestRatePrimary TODO
    /// @param interestRateSecondary TODO
    /// @return The unique identifier of the loan.
    function takeLoanFor(
        address borrower,
        uint256 loanAmount,
        uint256 addonAmount,
        uint256 durationInPeriods,
        uint256 interestRatePrimary,
        uint256 interestRateSecondary
    ) external returns (uint256);

    /// @dev TODO
    function autoRepayLoans(
        uint256[] calldata loanIds,
        uint256[] calldata amounts
    ) external;

    /// @dev Revokes a loan.
    /// @param loanId The unique identifier of the loan to revoke.
    function revokeLoan(uint256 loanId) external;

    /// @dev Freezes a loan.
    /// @param loanId The unique identifier of the loan to freeze.
    function freeze(uint256 loanId) external;

    /// @dev Unfreezes a loan.
    /// @param loanId The unique identifier of the loan to unfreeze.
    function unfreeze(uint256 loanId) external;

    /// @dev Updates the duration of a loan.
    /// @param loanId The unique identifier of the loan whose duration is to update.
    /// @param newDurationInPeriods The new duration of the loan, specified in periods.
    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external;

    /// @dev Updates the primary interest rate of a loan.
    /// @param loanId The unique identifier of the loan whose primary interest rate is to update.
    /// @param newInterestRate The new primary interest rate of the loan.
    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external;

    /// @dev Updates the secondary interest rate of a loan.
    /// @param loanId The unique identifier of the loan whose secondary interest rate is to update.
    /// @param newInterestRate The new secondary interest rate of the loan.
    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external;

    // -------------------------------------------- //
    //  Borrower functions                          //
    // -------------------------------------------- //

    /// @dev Repays a loan.
    /// @param loanId The unique identifier of the loan to repay.
    /// @param amount The amount to repay or `type(uint256).max` to repay the remaining balance of the loan.
    function repayLoan(uint256 loanId, uint256 amount) external;

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @dev Gets the stored state of a given loan.
    /// @param loanId The unique identifier of the loan to check.
    /// @return The stored state of the loan (see the Loan.State struct).
    function getLoanState(uint256 loanId) external view returns (Loan.State memory);

    /// @dev Gets the loan preview at a specific timestamp.
    /// @param loanId The unique identifier of the loan to check.
    /// @param timestamp The timestamp to get the loan preview for.
    /// @return The preview state of the loan (see the Loan.Preview struct).
    function getLoanPreview(uint256 loanId, uint256 timestamp) external view returns (Loan.Preview memory);

    /// @dev TODO
    function getBorrowerConfigByAddress(address borrower) external view returns (Borrower.Config memory);

    /// @dev TODO
    function getBorrowerConfigById(bytes32 id) external view returns (Borrower.Config memory);

    /// @dev TODO
    function getBorrowerConfigId(address borrower) external view returns (bytes32);

    /// @dev TODO
    function getBorrowerState(address borrower) external view returns (Borrower.State memory);

    /// @dev Returns the rate factor used to for interest rate calculations.
    function interestRateFactor() external view returns (uint256);

    /// @dev Returns the duration of a loan period specified in seconds.
    function periodInSeconds() external view returns (uint256);

    /// @dev Returns time offset.
    /// The time offset is used to adjust current period of the loan.
    function timeOffset() external view returns (int256);

    /// @dev Returns the total number of loans taken.
    function loanCounter() external view returns (uint256);

    /// @dev TODO
    function token() external view returns (address);

    /// @dev TODO
    function poolBalance() external view returns (uint256);

    /// @dev TODO
    function addonBalance() external view returns (uint256);
}

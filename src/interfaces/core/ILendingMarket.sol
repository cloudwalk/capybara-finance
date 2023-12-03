// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Loan} from "../../libraries/Loan.sol";

/// @title ILendingMarket interface
/// @notice Defines the lending market contract functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ILendingMarket {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when a credit line is registered
    /// @param lender The address of the credit line lender
    /// @param creditLine The address of the credit line contract
    event RegisterCreditLine(address indexed lender, address indexed creditLine);

    /// @notice Emitted when a liquidity pool is registered
    /// @param lender The address of the liquidity pool lender
    /// @param liquidityPool The address of the liquidity pool contract
    event RegisterLiquidityPool(address indexed lender, address indexed liquidityPool);

    /// @notice Emitted when a loan is taken
    /// @param loanId The unique identifier of the loan
    /// @param borrower The address of the borrower
    /// @param borrowAmount The initial principal amount of the loan
    event TakeLoan(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);

    /// @notice Emitted when a loan is repaid (fully or partially)
    /// @param loanId The unique identifier of the loan
    /// @param repayer The address of the repayer
    /// @param borrower The address of the borrower
    /// @param repayAmount The amount of the repayment
    /// @param remainingBalance The remaining balance of the loan
    event RepayLoan(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );

    /// @notice Emitted when a loan is frozen
    /// @param loanId The unique identifier of the loan
    /// @param freezeDate The date when the loan was frozen
    event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);

    /// @notice Emitted when a loan is unfrozen
    /// @param loanId The unique identifier of the loan
    /// @param unfreezeDate The date when the loan was unfrozen
    event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);

    /// @notice Emitted when the duration of the loan is updated
    /// @param loanId The unique identifier of the loan
    /// @param newDuration The new duration of the loan in periods
    /// @param oldDuration The old duration of the loan in periods
    event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);

    /// @notice Emitted when the moratorium of the loan is updated
    /// @param loanId The unique identifier of the loan
    /// @param fromDate The start date of the moratorium period
    /// @param moratorimPeriods The number of periods of the moratorium
    event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed fromDate, uint256 indexed moratorimPeriods);

    /// @notice Emitted when the primary interest rate of the loan is updated
    /// @param loanId The unique identifier of the loan
    /// @param newInterestRate The new primary interest rate of the loan
    /// @param oldInterestRate The old primary interest rate of the loan
    event UpdateLoanInterestRatePrimary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the secondary interest rate of the loan is updated
    /// @param loanId The unique identifier of the loan
    /// @param newInterestRate The new secondary interest rate of the loan
    /// @param oldInterestRate The old secondary interest rate of the loan
    event UpdateLoanInterestRateSecondary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the lender of the credit line is updated
    /// @param creditLine The address of the credit line contract
    /// @param newLender The address of the new lender
    /// @param oldLender The address of the old lender
    event UpdateCreditLineLender(address indexed creditLine, address indexed newLender, address indexed oldLender);

    /// @notice Emitted when the registry contract is updated
    /// @param newRegistry The address of the new registry
    /// @param oldRegistry The address of the old registry
    event SetRegistry(address indexed newRegistry, address indexed oldRegistry);

    /************************************************
     *  Borrower functions
     ***********************************************/

    /// @notice Takes a loan from a credit line
    /// @param creditLine The address of the desired credit line
    /// @param amount The desired loan amount
    /// @return The unique identifier of the loan
    function takeLoan(address creditLine, uint256 amount) external returns (uint256);

    /// @notice Repays a loan
    /// @param loanId The unique identifier of the loan to be repaid
    /// @param amount The repayment amount
    function repayLoan(uint256 loanId, uint256 amount) external;

    /************************************************
     *  Loan holder functions
     ***********************************************/

    /// @notice Freezes a loan
    /// @param loanId The unique identifier of the loan to be frozen
    function freeze(uint256 loanId) external;

    /// @notice Unfreezes a loan
    /// @param loanId The unique identifier of the loan to be unfrozen
    function unfreeze(uint256 loanId) external;

    /// @notice Updates the duration of a loan
    /// @param loanId The unique identifier of the loan whose duration is to be updated
    /// @param newDurationInPeriods The new duration of the loan, specified in periods
    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external;

    /// @notice Updates the moratorium of a loan
    /// @param loanId The unique identifier of the loan whose moratorium is to be updated
    /// @param newMoratoriumInPeriods The new moratorium of the loan, specified in periods
    function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods) external;

    /// @notice Updates the primary interest rate of a loan
    /// @param loanId The unique identifier of the loan whose primary interest rate is to be updated
    /// @param newInterestRate The new primary interest rate of the loan
    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external;

    /// @notice Updates the secondary interest rate of a loan
    /// @param loanId The unique identifier of the loan whose secondary interest rate is to be updated
    /// @param newInterestRate The new secondary interest rate of the loan
    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external;

    /// @notice Updates the lender associated with a credit line
    /// @param creditLine The address of the credit line whose lender is to be updated
    /// @param newLender The address of the new lender
    function updateLender(address creditLine, address newLender) external;

    /// @notice Registers a credit line
    /// @param lender The address of the credit line lender
    /// @param creditLine The address of the credit line contract
    function registerCreditLine(address lender, address creditLine) external;

    /// @notice Registers a liquidity pool
    /// @param lender The address of the liquidity pool lender
    /// @param liquidityPool The address of the liquidity pool contract
    function registerLiquidityPool(address lender, address liquidityPool) external;

    /************************************************
     *  View functions
     ***********************************************/

    /// @notice Retrieves the credit line lender
    /// @param creditLine The address of the credit line to check
    function getLender(address creditLine) external view returns (address);

    /// @notice Retrieves the lender's liquidity pool
    /// @param lender The address of the lender to check
    function getLiquidityPool(address lender) external view returns (address);

    /// @notice Retrieves the current state of a loan
    /// @param loanId The unique identifier of the loan to check
    /// @return The struct containing the stored state of the loan
    function getLoan(uint256 loanId) external view returns (Loan.State memory);

    /// @notice Retrieves the preview state of a loan given a repayment amount and date
    /// @param loanId The unique identifier of the loan to check
    /// @param repayAmount The amount to be repaid in the preview
    /// @param repayDate The date of the repayment in the preview
    /// @return The struct containing the preview state of the loan
    function getLoanPreview(uint256 loanId, uint256 repayAmount, uint256 repayDate)
        external
        view
        returns (Loan.State memory);

    /// @notice Retrieves the outstanding balance of a loan
    /// @param loanId The unique identifier of the loan to check
    function getOutstandingBalance(uint256 loanId) external view returns (uint256);

    /// @notice Retrieves the current period of the loan
    /// @param loanId The unique identifier of the loan to check
    function getCurrentPeriodDate(uint256 loanId) external view returns (uint256);

    /// @notice Retrieves the registry address
    function registry() external view returns (address);
}

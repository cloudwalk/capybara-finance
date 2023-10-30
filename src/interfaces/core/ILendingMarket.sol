// SPDX-License-Identifier: MIT

import {Loan} from "../../libraries/Loan.sol";

pragma solidity 0.8.20;

/// @title ILendingMarket interface
/// @notice Defines the lending market functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ILendingMarket {
    /************************************************
     *  EVENTS
     ***********************************************/

    /// @notice Emitted when a credit line is registered
    /// @param lender The address of the credit line lender
    /// @param creditLine The address of the credit line contract
    event CreditLineRegistered(address indexed lender, address indexed creditLine);

    /// @notice Emitted when a liquidity pool is registered
    /// @param lender The address of the liquidity pool lender
    /// @param liquidityPool The address of the liquidity pool contract
    event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);

    /// @notice Emitted when a loan is taken
    /// @param loandId The unique identifier of the loan
    /// @param borrower The address of the borrower
    /// @param borrowAmount The initial principal amount of the loan
    event LoanTaken(uint256 indexed loandId, address indexed borrower, uint256 borrowAmount);

    /// @notice Emitted when a loan is repaid (fully)
    /// @param loandId The unique identifier of the loan
    event LoanRepaid(uint256 indexed loandId, address indexed borrower);

    /// @notice Emitted when a loan is repaid (fully or partially)
    /// @param loandId The unique identifier of the loan
    /// @param repayer The address of the repayer
    /// @param borrower The address of the borrower
    /// @param repayAmount The amount of the repayment
    /// @param remainingBalance The remaining balance of the loan
    event LoanRepayment(
        uint256 indexed loandId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );

    /// @notice Emitted when the status of the loan is changed
    /// @param loandId The unique identifier of the loan
    /// @param newStatus The new status of the loan
    /// @param oldStatus The old status of the loan
    event LoanStatusChanged(uint256 indexed loandId, Loan.Status indexed newStatus, Loan.Status indexed oldStatus);

    /// @notice Emitted when the duration of the loan is updated
    /// @param loandId The unique identifier of the loan
    /// @param newDuration The new duration of the loan in periods
    /// @param oldDuration The old duration of the loan in periods
    event LoanDurationUpdated(uint256 indexed loandId, uint256 indexed newDuration, uint256 indexed oldDuration);

    /// @notice Emitted when the moratorium of the loan is updated
    /// @param loandId The unique identifier of the loan
    /// @param newMoratorium The new moratorium of the loan in periods
    /// @param oldMoratorium The old moratorium of the loan in periods
    event LoanMoratoriumUpdated(uint256 indexed loandId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);

    /// @notice Emitted when the primary interest rate of the loan is updated
    /// @param loandId The unique identifier of the loan
    /// @param newInterestRate The new primary interest rate of the loan
    /// @param oldInterestRate The old primary interest rate of the loan
    event LoanInterestRatePrimaryUpdated(
        uint256 indexed loandId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the secondary interest rate of the loan is updated
    /// @param loandId The unique identifier of the loan
    /// @param newInterestRate The new secondary interest rate of the loan
    /// @param oldInterestRate The old secondary interest rate of the loan
    event LoanInterestRateSecondaryUpdated(
        uint256 indexed loandId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the lender of the credit line is updated
    /// @param creditLine The address of the credit line contract
    /// @param newLender The address of the new lender
    /// @param oldLender The address of the old lender
    event CreditLineLenderUpdated(address indexed creditLine, address indexed newLender, address indexed oldLender);

    /// @notice Emitted when the registry contract is updated
    /// @param oldRegistry The address of the old registry
    /// @param newRegistry The address of the new registry
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    /************************************************
     *  BORROWER FUNCTIONS
     ***********************************************/

    /// @notice Takes a loan from a credit line
    /// @param creditLine The address of the desired credit line
    /// @param amount The desired loan amount
    function takeLoan(address creditLine, uint256 amount) external;

    /// @notice Repays a loan
    /// @param loanId The unique identifier of the loan to be repaid
    /// @param amount The repayment amount
    function repayLoan(uint256 loanId, uint256 amount) external;

    /************************************************
     *  LOAN HOLDER FUNCTIONS
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
     *  VIEW FUNCTIONS
     ***********************************************/

    /// @notice Retrieves the credit line lender
    /// @param creditLine The address of the credit line to check
    /// @return The address of the lender associated with a credit line
    function getLender(address creditLine) external view returns (address);

    /// @notice Retrieves the lender's liquidity pool
    /// @param lender The address of the lender to check
    /// @return The address of the liquidity pool associated with a lender
    function getLiquidityPool(address lender) external view returns (address);

    /// @notice Retrieves the stored state of a loan
    /// @param loanId The unique identifier of the loan to check
    /// @return The struct containing the stored state of the loan
    function getLoanStored(uint256 loanId) external view returns (Loan.State memory);

    /// @notice Retrieves the current state of a loan
    /// @param loanId The unique identifier of the loan to check
    /// @return The struct containing the current state of the loan
    function getLoanCurrent(uint256 loanId) external view returns (Loan.Status, Loan.State memory);
}

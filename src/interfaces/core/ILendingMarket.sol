// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Loan } from "../../libraries/Loan.sol";

/// @title ILendingMarket interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the lending market contract functions and events.
interface ILendingMarket {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @notice Emitted when a credit line is registered.
    /// @param lender The address of the credit line lender.
    /// @param creditLine The address of the credit line contract.
    event RegisterCreditLine(address indexed lender, address indexed creditLine);

    /// @notice Emitted when a liquidity pool is registered.
    /// @param lender The address of the liquidity pool lender.
    /// @param liquidityPool The address of the liquidity pool contract.
    event RegisterLiquidityPool(address indexed lender, address indexed liquidityPool);

    /// @notice Emitted when a loan is taken.
    /// @param loanId The unique identifier of the loan.
    /// @param borrower The address of the borrower of the loan.
    /// @param borrowAmount The initial principal amount of the loan.
    event TakeLoan(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);

    /// @notice Emitted when a loan is repaid (fully or partially).
    /// @param loanId The unique identifier of the loan.
    /// @param repayer The address of the repayer (borrower or third-party).
    /// @param borrower The address of the borrower of the loan.
    /// @param repayAmount The amount of the repayment.
    /// @param remainingBalance The remaining balance of the loan.
    event RepayLoan(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );

    /// @notice Emitted when a loan is frozen.
    /// @param loanId The unique identifier of the loan.
    /// @param freezeDate The date when the loan was frozen.
    event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);

    /// @notice Emitted when a loan is unfrozen.
    /// @param loanId The unique identifier of the loan.
    /// @param unfreezeDate The date when the loan was unfrozen.
    event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);

    /// @notice Emitted when the duration of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newDuration The new duration of the loan in periods.
    /// @param oldDuration The old duration of the loan in periods.
    event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);

    /// @notice Emitted when the moratorium of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param fromDate The start date of the moratorium period.
    /// @param moratorimPeriods The number of periods of the moratorium.
    event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed fromDate, uint256 indexed moratorimPeriods);

    /// @notice Emitted when the primary interest rate of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newInterestRate The new primary interest rate of the loan.
    /// @param oldInterestRate The old primary interest rate of the loan.
    event UpdateLoanInterestRatePrimary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the secondary interest rate of the loan is updated.
    /// @param loanId The unique identifier of the loan.
    /// @param newInterestRate The new secondary interest rate of the loan.
    /// @param oldInterestRate The old secondary interest rate of the loan.
    event UpdateLoanInterestRateSecondary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /// @notice Emitted when the lending markt registry is updated.
    /// @param newRegistry The address of the new registry.
    /// @param oldRegistry The address of the old registry.
    event SetRegistry(address indexed newRegistry, address indexed oldRegistry);

    /// @notice Emitted when a lender alias is configured.
    /// @param lender The address of the lender account.
    /// @param account The address of the alias account.
    /// @param isAlias True if the account is configured as an alias, otherwise false.
    event ConfigureLenderAlias(address indexed lender, address indexed account, bool isAlias);

    /// @notice Emitted when a liquidity pool is assigned to a credit line.
    /// @param creditLine The address of the credit line.
    /// @param newLiquidityPool The address of the new liquidity pool.
    /// @param oldLiquidityPool The address of the old liquidity pool.
    event AssignLiquidityPoolToCreditLine(
        address indexed creditLine, address indexed newLiquidityPool, address indexed oldLiquidityPool
    );

    // -------------------------------------------- //
    //  Borrower functions                          //
    // -------------------------------------------- //

    /// @notice Takes a loan.
    /// @param creditLine The address of the desired credit line.
    /// @param borrowAmount The desired amount of the loan.
    /// @return The unique identifier of the loan.
    function takeLoan(address creditLine, uint256 borrowAmount) external returns (uint256);

    /// @notice Repays a loan.
    /// @param loanId The unique identifier of the loan to repay.
    /// @param repayAmount The amount to repay.
    function repayLoan(uint256 loanId, uint256 repayAmount) external;

    // -------------------------------------------- //
    //  Lender functions                            //
    // -------------------------------------------- //

    /// @notice Freezes a loan.
    /// @param loanId The unique identifier of the loan to freeze.
    function freeze(uint256 loanId) external;

    /// @notice Unfreezes a loan.
    /// @param loanId The unique identifier of the loan to unfreeze.
    function unfreeze(uint256 loanId) external;

    /// @notice Updates the duration of the loan.
    /// @param loanId The unique identifier of the loan whose duration is to update.
    /// @param newDurationInPeriods The new duration of the loan, specified in periods.
    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external;

    /// @notice Updates the moratorium of the loan.
    /// @param loanId The unique identifier of the loan whose moratorium is to update.
    /// @param newMoratoriumInPeriods The new moratorium of the loan, specified in periods.
    function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods) external;

    /// @notice Updates the primary interest rate of the loan.
    /// @param loanId The unique identifier of the loan whose primary interest rate is to update.
    /// @param newInterestRate The new primary interest rate of the loan.
    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external;

    /// @notice Updates the secondary interest rate of the loan.
    /// @param loanId The unique identifier of the loan whose secondary interest rate is to update.
    /// @param newInterestRate The new secondary interest rate of the loan.
    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external;

    /// @notice Registers a credit line.
    /// @param lender The address of the credit line lender.
    /// @param creditLine The address of the credit line.
    function registerCreditLine(address lender, address creditLine) external;

    /// @notice Registers a liquidity pool.
    /// @param lender The address of the liquidity pool lender.
    /// @param liquidityPool The address of the liquidity pool.
    function registerLiquidityPool(address lender, address liquidityPool) external;

    /// @notice Updates the lender of a given credit line.
    /// @param creditLine The address of the credit line to update.
    /// @param newLender The address of the new lender of the credit line.
    function updateCreditLineLender(address creditLine, address newLender) external;

    /// @notice Updates the lender of a given liquidity pool.
    /// @param liquidityPool The address of the liquidity pool to update.
    /// @param newLender The address of the new lender of the liquidity pool.
    function updateLiquidityPoolLender(address liquidityPool, address newLender) external;

    /// @notice Assigns a liquidity pool to a credit line.
    /// @param creditLine The address of the credit line.
    /// @param liquidityPool The address of the liquidity pool.
    function assignLiquidityPoolToCreditLine(address creditLine, address liquidityPool) external;

    /// @notice Configures an alias for a lender.
    /// @param account The address to configure as an alias.
    /// @param isAlias True if the account is an alias, otherwise false.
    function configureAlias(address account, bool isAlias) external;

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @notice Gets the credit line's lender.
    /// @param creditLine The address of the credit line to check.
    /// @return The address of the lender of the credit line.
    function getCreditLineLender(address creditLine) external view returns (address);

    /// @notice Gets the liquidity pool's lender.
    /// @param liquidityPool The address of the liquidity pool to check.
    /// @return The address of the lender of the liquidity pool.
    function getLiquidityPoolLender(address liquidityPool) external view returns (address);

    /// @notice Gets the liquidity pool assigned to a credit line.
    /// @param liquidityPool The address of the liquidity pool to check.
    /// @return The address of the credit line that the liquidity pool is assigned to.
    function getLiquidityPoolByCreditLine(address liquidityPool) external view returns (address);

    /// @notice Gets the stored state of a given loan.
    /// @param loanId The unique identifier of the loan to check.
    /// @return The stored state of the loan (see Loan.State struct).
    function getLoanState(uint256 loanId) external view returns (Loan.State memory);

    /// @notice Gets the loan preview at a specific timestamp.
    /// @param loanId The unique identifier of the loan to check.
    /// @param timestamp The timestamp to get the loan preview for.
    /// @return The preview state of the loan (see Loan.Preview struct).
    function getLoanPreview(uint256 loanId, uint256 timestamp) external view returns (Loan.Preview memory);

    /// @notice Checks if the account is an alias for a lender.
    /// @param lender The address of the lender to check alias for.
    /// @param account The address to check whether it's an alias or not.
    /// @return True if the account is an alias for the lender, otherwise false.
    function hasAlias(address lender, address account) external view returns (bool);

    /// @notice Returns the address of the lending market registry.
    function registry() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Loan } from "src/common/libraries/Loan.sol";

/// @title ICreditLine interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the credit line contract functions and events.
interface ICreditLine {
    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @notice A hook that is triggered by the market before a loan is taken.
    /// @param borrower The address of the borrower.
    /// @param borrowAmount The desired amount of tokens to borrow.
    /// @param durationInPeriods The desired duration of the loan in periods.
    /// @param loanId The unique identifier of the loan.
    /// @return terms The struct containing the terms of the loan.
    function onBeforeLoanTaken(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods,
        uint256 loanId
    ) external returns (Loan.Terms memory terms);

    /// @notice Retrieves the loan terms for the provided borrower and the amount.
    /// @param borrower The address of the borrower.
    /// @param borrowAmount The desired amount of tokens to borrow.
    /// @param durationInPeriods The desired duration of the loan in periods.
    /// @return terms The struct containing the terms of the loan.
    function determineLoanTerms(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods
    ) external view returns (Loan.Terms memory terms);

    /// @notice Returns the address of the associated lending market.
    function market() external view returns (address);

    /// @notice Returns the address of the credit line lender.
    function lender() external view returns (address);

    /// @notice Returns the address of the credit line token.
    function token() external view returns (address);

    /// @notice Returns the kind of the credit line.
    function kind() external view returns (uint16);
}

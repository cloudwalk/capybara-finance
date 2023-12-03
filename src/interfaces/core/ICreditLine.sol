// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Loan} from "../../libraries/Loan.sol";

/// @title ICreditLine interface
/// @notice Defines the credit line contract functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ICreditLine {
    /************************************************
     *  Functions
     ***********************************************/

    /// @notice A hook that is triggered by the market when a loan is taken
    /// @param borrower The address of the borrower
    /// @param amount The amount of the loan
    /// @return terms The struct containing the terms of the loan
    function onTakeLoan(address borrower, uint256 amount) external returns (Loan.Terms memory terms);

    /// @notice Retrieves the loan terms for the provided borrower and amount
    /// @param borrower The address of the borrower
    /// @param amount The amount of the loan
    /// @return terms The struct containing the terms of the loan
    function determineLoanTerms(address borrower, uint256 amount) external view returns (Loan.Terms memory terms);

    /// @notice Returns the address of the associated lending market
    function market() external view returns (address);

    /// @notice Returns the address of the credit line lender
    function lender() external view returns (address);

    /// @notice Returns the address of the credit line token
    function token() external view returns (address);

    /// @notice Returns the kind of the credit line
    function kind() external view returns (uint16);
}

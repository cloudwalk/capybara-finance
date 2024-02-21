// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title ILiquidityPool interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Defines the liquidity pool contract functions and events
interface ILiquidityPool {
    /************************************************
     *  Functions
     ***********************************************/

    /// @notice A hook that is triggered by the market before a loan is taken
    /// @param loanId The unique identifier of the loan being taken
    /// @param creditLine The address of the associated credit line
    function onBeforeLoanTaken(uint256 loanId, address creditLine) external returns (bool);

    /// @notice A hook that is triggered by the market after a loan is taken
    /// @param loanId The unique identifier of the loan being taken
    /// @param creditLine The address of the associated credit line
    function onAfterLoanTaken(uint256 loanId, address creditLine) external returns (bool);

    /// @notice A hook that is triggered by the market before the loan payment
    /// @param loanId The unique identifier of the loan being paid
    /// @param repayAmount The amount to be repaid
    function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);

    /// @notice A hook that is triggered by the market after the loan payment
    /// @param loanId The unique identifier of the loan being paid
    /// @param repayAmount The amount that was repaid
    function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);

    /// @notice Returns the address of the associated lending market
    function market() external view returns (address);

    /// @notice Returns the address of the liquidity pool lender
    function lender() external view returns (address);

    /// @notice Returns the kind of the liquidity pool
    function kind() external view returns (uint16);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title ILiquidityPool interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the liquidity pool contract functions and events.
interface ILiquidityPool {
    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev A hook that is triggered by the associated market before a loan is taken.
    /// @param loanId The unique identifier of the loan being taken.
    /// @param creditLine The address of the credit line.
    function onBeforeLoanTaken(uint256 loanId, address creditLine) external returns (bool);

    /// @dev A hook that is triggered by the associated market after a loan is taken.
    /// @param loanId The unique identifier of the loan being taken.
    /// @param creditLine The address of the credit line.
    function onAfterLoanTaken(uint256 loanId, address creditLine) external returns (bool);

    /// @dev A hook that is triggered by the associated market before the loan payment.
    /// @param loanId The unique identifier of the loan being paid.
    /// @param repayAmount The amount of tokens to be repaid.
    function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);

    /// @dev A hook that is triggered by the associated market after the loan payment.
    /// @param loanId The unique identifier of the loan being paid.
    /// @param repayAmount The amount of tokens that was repaid.
    function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool);

    /// @dev Returns the address of the associated lending market.
    function market() external view returns (address);

    /// @dev Returns the address of the liquidity pool lender.
    function lender() external view returns (address);

    /// @dev Returns the kind of the liquidity pool.
    function kind() external view returns (uint16);
}
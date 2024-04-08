// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./core/ILiquidityPool.sol";

/// @title ILiquidityPoolAccountable interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the accountable liquidity pool contract functions and events.
interface ILiquidityPoolAccountable is ILiquidityPool {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @dev Emitted when an account is configured as an admin.
    /// @param account The address of the admin account.
    /// @param adminStatus True if the account is an admin.
    event AdminConfigured(address indexed account, bool adminStatus);

    /// @dev Emitted when tokens are deposited to the liquidity pool.
    /// @param creditLine The address of the credit line.
    /// @param amount The amount of tokens deposited.
    event Deposit(address indexed creditLine, uint256 amount);

    /// @dev Emitted when tokens are withdrawn from the liquidity pool.
    /// @param tokenSource The address of the token source.
    /// @param amount The amount of tokens withdrawn.
    event Withdrawal(address indexed tokenSource, uint256 amount);

    /// @dev Emitted when loan auto repayment was initiated.
    /// @param numberOfLoans The number of loans repaid.
    event AutoRepayment(uint256 numberOfLoans);

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Configures the admin status for an account.
    /// @param account The address of the account to configure as an admin.
    /// @param adminStatus True whether the account is an admin.
    function configureAdmin(address account, bool adminStatus) external;

    /// @dev Deposits tokens to the liquidity pool.
    /// @param creditLine The address of the credit line.
    /// @param amount The amount of tokens to deposit.
    function deposit(address creditLine, uint256 amount) external;

    /// @dev Withdraws tokens from the liquidity pool.
    /// @param tokenSource The address of the token source.
    /// @param amount The amount of tokens to withdraw.
    function withdraw(address tokenSource, uint256 amount) external;

    /// @dev Executes auto repayment of loans in the batch mode.
    /// @param loanIds The unique identifiers of the loans to repay.
    /// @param amounts The payment amounts that correspond with given loan ids.
    function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external;

    /// @dev Retrieves the token balance of a given token source.
    /// @param tokenSource The address of the token source.
    /// @return The token balance of the token source.
    function getTokenBalance(address tokenSource) external view returns (uint256);

    /// @dev Retrieves the credit line associated with a loan.
    /// @param loanId The unique identifier of the loan.
    /// @return The address of the credit line.
    function getCreditLine(uint256 loanId) external view returns (address);

    /// @dev Checks whether an account is an admin.
    /// @param account The address of the account to check.
    /// @return True if the account is configured as an admin.
    function isAdmin(address account) external view returns (bool);
}

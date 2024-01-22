// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/// @title ILiquidityPoolAccountable interface
/// @notice Defines the accountable liquidity pool contract functions and events
/// @author CloudWalk Inc. (See https://cloudwalk.io)
interface ILiquidityPoolAccountable {
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when tokens are deposited to the liquidity pool
    /// @param creditLine The address of the associated credit line
    /// @param amount The amount of tokens deposited
    event Deposit(address indexed creditLine, uint256 amount);

    /// @notice Emitted when tokens are withdrawn from the liquidity pool
    /// @param tokenSource The address of the associated token source
    /// @param amount The amount of tokens withdrawn
    event Withdraw(address indexed tokenSource, uint256 amount);

    /// @notice Emitted when admin is configured
    /// @param admin The address of the admin account
    /// @param adminStatus True if the account is an admin
    event ConfigureAdmin(address indexed admin, bool adminStatus);

    /// @notice Emitted when liqudiity pool is repay loans
    /// @param loanIds The unique identifiers of the loans for repayment
    /// @param amounts The amounts that corellate with given loan ids
    event RepayLoans(uint256[] loanIds, uint256[] amounts);

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Configures an admin status
    /// @param admin The address of the admin to configure
    /// @param adminStatus True whether the account is an admin
    function configureAdmin(address admin, bool adminStatus) external;

    /// @notice Depisits tokens to the liquidity pool
    /// @param creditLine The address of the associated credit line
    /// @param amount The amount of tokens to deposit
    function deposit(address creditLine, uint256 amount) external;

    /// @notice Withdraws tokens from the liquidity pool
    /// @param tokenSource The address of the associated token source
    /// @param amount The amount of tokens to withdraw
    function withdraw(address tokenSource, uint256 amount) external;

    /// @notice Retrieves the credit line associated with the loan
    /// @param loanId The unique identifier of the loan
    /// @return The address of the credit line
    function getCreditLine(uint256 loanId) external view returns (address);

    /// @notice Retrieves the token balance of the token source
    /// @param tokenSource The address of the token source
    /// @return The token balance
    function getTokenBalance(address tokenSource) external view returns (uint256);

    /// @notice Repay batch loans
    /// @param loanIds The unique identifiers of the loans for repayment
    /// @param amounts The amounts that corellate with given loan ids
    function repayLoans(uint256[] memory loanIds, uint256[] memory amounts) external;

    /// @notice Checks whether an account is an admin
    /// @param account The address of the account to check
    /// @return True if the account is configured as an admin
    function isAdmin(address account) external view returns (bool);
}

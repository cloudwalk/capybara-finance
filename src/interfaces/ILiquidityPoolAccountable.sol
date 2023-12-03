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

    /************************************************
     *  Functions
     ***********************************************/

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
}

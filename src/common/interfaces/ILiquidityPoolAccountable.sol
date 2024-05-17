// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./core/ILiquidityPool.sol";

/// @title ILiquidityPoolAccountable interface
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the accountable liquidity pool contract functions and events.
interface ILiquidityPoolAccountable is ILiquidityPool {
    // -------------------------------------------- //
    //  Structs and enums                           //
    // -------------------------------------------- //

    /// @dev A struct that defines the credit line balance.
    struct CreditLineBalance {
        uint64 borrowable; // The amount of tokens that can be borrowed.
        uint64 addons;     // The amount of tokens that are locked as addons.
    }

    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @dev Emitted when tokens are deposited to the liquidity pool.
    /// @param amount The amount of tokens deposited.
    event Deposit(uint256 amount);

    /// @dev Emitted when tokens are withdrawn from the liquidity pool.
    /// @param borrowableAmount The amount of tokens withdrawn from the borrowable balance.
    /// @param addonAmount The amount of tokens withdrawn from the addons balance.
    event Withdrawal(uint256 borrowableAmount, uint256 addonAmount);

    /// @dev Emitted when tokens are rescued from the liquidity pool.
    /// @param token The address of the token rescued.
    /// @param amount The amount of tokens rescued.
    event Rescue(address indexed token, uint256 amount);

    /// @dev Emitted when loan auto repayment was initiated.
    /// @param numberOfLoans The number of loans repaid.
    event AutoRepayment(uint256 numberOfLoans);

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @dev Deposits tokens to the liquidity pool.
    /// @param amount The amount of tokens to deposit.
    function deposit(uint256 amount) external;

    /// @dev Withdraws tokens from the liquidity pool.
    /// @param borrowableAmount The amount of tokens to withdraw from the borrowable balance.
    /// @param addonAmount The amount of tokens to withdraw from the addons balance.
    function withdraw(uint256 borrowableAmount, uint256 addonAmount) external;

    /// @dev Rescues tokens from the liquidity pool.
    /// @param token The address of the token to rescue.
    /// @param amount The amount of tokens to rescue.
    function rescue(address token, uint256 amount) external;

    /// @dev Executes auto repayment of loans in the batch mode.
    /// @param loanIds The unique identifiers of the loans to repay.
    /// @param amounts The payment amounts that correspond with given loan ids.
    function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external;

    /// @dev Gets the borrowable and addons balances of the liquidity pool.
    /// @return The borrowable and addons balances.
    function getBalances() external view returns (uint256, uint256);

    /// @dev Checks whether an account is an admin.
    /// @param account The address of the account to check.
    /// @return True if the account is configured as an admin.
    function isAdmin(address account) external view returns (bool);
}

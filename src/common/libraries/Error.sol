// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @title Error library
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines common error types used across the contracts.
library Error {
    /// @dev Thrown when the specified address is zero.
    error ZeroAddress();

    /// @dev Thrown when the specified amount is invalid.
    error InvalidAmount();

    /// @dev Thrown when the configuration is already applied.
    error AlreadyConfigured();

    /// @dev Thrown when array lengths do not match each other.
    error ArrayLengthMismatch();

    /// @dev TODO
    error ActiveLoanCounterExceeded();

    /// @dev TODO
    error AddonBalanceInsufficient();

    /// @dev TODO
    error BorrowerNonConfigured();

    /// @dev TODO
    error BorrowerConfigExpired();

    /// @dev TODO
    error BorrowerConfigInvalid();

    /// @dev TODO
    error BorrowerAllowanceInsufficient();

    /// @dev TODO
    error ConfigIdInvalid();

    /// @dev Thrown when the loan is already repaid.
    error LoanAlreadyRepaid();

    /// @dev Thrown when the loan is already frozen.
    error LoanAlreadyFrozen();

    /// @dev Thrown when provided loan duration is inappropriate.
    error LoanDurationInappropriate();

    /// @dev Thrown when the loan does not exist.
    error LoanNonExistent();

    /// @dev Thrown when the loan is not frozen.
    error LoanNotFrozen();

    /// @dev Thrown when the loan state is inappropriate for the requested action.
    error LoanStateInappropriate(uint256 loanId);

    /// @dev Thrown when provided interest rate is inappropriate.
    error InterestRateInappropriate();

    /// @dev TODO
    error PoolBalanceInsufficient();
}

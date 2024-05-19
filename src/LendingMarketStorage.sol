// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Borrower } from "src/common/libraries/Borrower.sol";
import { Loan } from "src/common/libraries/Loan.sol";

/// @title LendingMarketStorage contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Defines the storage layout for the lending market contract.
abstract contract LendingMarketStorage {
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @dev The loan identifier counter.
    uint256 internal _loanCounter;

    address internal _token;

    uint64 internal _poolBalance;

    //uint32 internal _reserved

    uint64 internal _addonBalance;

    //uint192 internal _reserved

    /// @dev The mapping of loan id to its state.
    mapping(uint256 => Loan.State) internal _loans;

    /// @dev TODO
    mapping(bytes32 => Borrower.Config) internal _borrowerConfigs;

    /// @dev TODO
    mapping(address => bytes32) internal _borrowerConfigIds;

    /// @dev TODO
    mapping(address => Borrower.State) internal _borrowerStates;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain.
    uint256[43] private __gap;
}

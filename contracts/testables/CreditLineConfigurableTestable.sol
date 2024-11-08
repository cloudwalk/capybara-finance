// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { CreditLineConfigurable } from "../credit-lines/CreditLineConfigurable.sol";

/// @title CreditLineConfigurableTestable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Version of the configurable credit line contract with additions required for testing.
contract CreditLineConfigurableTestable is CreditLineConfigurable {
    /// @dev Sets the borrower state for testing purposes.
    /// @param borrower The address of the borrower.
    /// @param newState The new borrower state.
    function setBorrowerState(address borrower, BorrowerState calldata newState) external {
        _borrowerStates[borrower] = newState;
    }

    /// @dev Sets the migration state for testing purposes.
    /// @param newState The new migration state.
    function setMigrationState(MigrationState calldata newState) external {
        _migrationState = newState;
    }
}

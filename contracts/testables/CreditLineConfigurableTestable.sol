// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { CreditLineConfigurable } from "../credit-lines/CreditLineConfigurable.sol";

/// @title CreditLineConfigurableTestable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Version of the configurable credit line contract with additions required for testing.
contract CreditLineConfigurableTestable is CreditLineConfigurable {
    /// @dev TODO
    function setBorrowerState(address borrower, BorrowerState calldata newState) external {
        _borrowerStates[borrower] = newState;
    }

    /// @dev TODO
    function setMigrationState(MigrationState calldata newState) external {
        _migrationState = newState;
    }
}

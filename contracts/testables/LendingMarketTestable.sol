// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { LendingMarket } from "../LendingMarket.sol";

/// @title LendingMarketTestable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Version of the lending market contract with additions required for testing.
contract LendingMarketTestable is LendingMarket {
    /// @dev Sets a new credit line address for a lending program.
    /// @param programId The ID of the lending program.
    /// @param newCreditLine The new address of the credit line to set.
    function setCreditLineForProgram(uint32 programId, address newCreditLine) external {
        _programCreditLines[programId] = newCreditLine;
    }

    /// @dev Sets a new liquidity pool address for a lending program.
    /// @param programId The ID of the lending program.
    /// @param newLiquidityPool The new address of the liquidity pool to set.
    function setLiquidityPoolForProgram(uint32 programId, address newLiquidityPool) external {
        _programLiquidityPools[programId] = newLiquidityPool;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { OutstandingBalance_v2 } from "src/OutstandingBalance_v2.sol";

/// @title LendingMarketComplexTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains complex tests for the LendingMarket contract.
contract LendingMarketComplexTest is Test {
    OutstandingBalance_v2 private balanceCalculationContract;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //
    uint256[] public numberOfPeriods;
    uint256[] public interestRates;

    function setUp() public {
        balanceCalculationContract = new OutstandingBalance_v2();
    }

    function test_balance_v2() public {
        uint256 originalBalance = 5000000000;
        numberOfPeriods = [3, 6, 9, 12, 24, 36];
//        interestRates = [4167, 8333, 12500, 16667, 25000, 41667, 125000, 250000]; //5,10,15,20,30,50,150,300 %
        interestRates = [8333, 41667, 125000, 250000, 416667]; //10,50,150,300,500 %
        uint256 interestRate = 8333;
        uint256 interestRateFactor = 1000000;
        for (uint256 j = 0; j < interestRates.length; j++) {
            for (uint256 i = 0; i < numberOfPeriods.length; i++) {
                uint256 outstandingBalance = balanceCalculationContract.calculateOutstandingBalance2(
                    originalBalance,
                    numberOfPeriods[i],
                    interestRates[j],
                    interestRateFactor
                );
                console.log("R  : ", interestRates[j]);
                console.log("C  : ", outstandingBalance);
            }
            console.log("\n\n");
        }
    }
}

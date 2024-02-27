// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";

contract ComplexScenarios is Test {
    struct LoanParameters {
        uint32 interestRatePrimary;
        uint32 interestRateSecondary;
        Interest.Formula interestFormula;
        address addonRecipient;
        uint32 periodInSeconds;
        uint32 durationInPeriods;
        uint32 interestRateFactor;
        uint32 addonPeriodCostRate;
        uint32 addonFixedCostRate;
        uint256 borrowAmount;
        uint8 tokenDecimals;
        uint256 step;
        uint256[] repayments;
        uint256[] expectedOutstandingBalances;
    }

    // Scenario 1: No repayments, both primary & secondary interest rate used
    uint256[] public REPAYMENTS_CASE_1 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_1 =
        [1000000000, 3862959577, 14922456692, 57644846986, 222679713710, 860202732605, 12387796729764, 178396908079124, 2569097436000000, 36997623474000000];

    // Scenario 2: Instant full repayment
    uint256[] public REPAYMENTS_CASE_2 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_2 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    // Scenario 3: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    uint256[] public REPAYMENTS_CASE_3 =
        [500000000, 200000000, 1500000000, 8000000000, 25000000000, 75000000000, 100000000000, 240000000000, 128000000000, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_3 =
        [1000000000, 1931479788, 6688636429, 20043492783, 46523525783, 83144510047, 117289251826, 248982860798, 129362357732, 18174440904, 0];

    // Scenario 4: Partial repayment each period until full repayment, both primary & secondary interest rate used
    uint256[] public REPAYMENTS_CASE_4 =
        [100000000, 50000000, 100000000, 50000000, 100000000, 50000000, 100000000, 50000000, 100000000, 50000000, 100000000, 50000000, 100000000, 50000000, 100000000, 50000000, type(uint256).max];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_4 =
        [1000000000, 924657534, 898620754, 820500775, 791610385, 710558615, 678656111, 594509703, 559427777, 472014839, 433576889, 351855075, 318395079, 230361933, 190244779, 95189698, 47665846];

    // Scenario 5: Half of full amount before default, second half after
    uint256[] public REPAYMENTS_CASE_5 =
        [0, 0, 0, 0, 0, 43101000000, 0, 0, 0, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_5 =
        [1000000000, 3862959577, 14922456692, 57644846986, 222679713710, 860202732605, 11767098368073, 169458218577592, 2440371190000000, 35143834235000000, 0];

    // Scenario 6: Secondary interest rate is zero
    uint256[] public REPAYMENTS_CASE_6 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_6 =
        [1000000000, 3862959577, 14922456692, 57644846986, 222679713710, 860202732605, 860202732605, 860202732605, 860202732605, 860202732605];

    // Scenario 7: Primary interest rate is zero
    uint256[] public REPAYMENTS_CASE_7 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_7 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 14401019969, 207389376150, 2986618547326, 43010353340281];

    // Scenario 7: Both primary and secondary interest rates are zero
    uint256[] public REPAYMENTS_CASE_8 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_8 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000];

    function LOAN_CASE_1() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_1,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_1
        });
    }

    function LOAN_CASE_2() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_2,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_2
        });
    }

    function LOAN_CASE_3() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_3,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_3
        });
    }

    function LOAN_CASE_4() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 10,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 1,
            repayments : REPAYMENTS_CASE_4,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_4
        });
    }

    function LOAN_CASE_5() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_5,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_5
        });
    }

    function LOAN_CASE_6() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 27397260,     // 10 %
            interestRateSecondary : 0,          // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_6,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_6
        });
    }

    function LOAN_CASE_7() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,            // 10 %
            interestRateSecondary : 54794520,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_7,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_7
        });
    }

    function LOAN_CASE_8() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,                      // 0 %
            interestRateSecondary : 0,                    // 0 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_8,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_8
        });
    }
}
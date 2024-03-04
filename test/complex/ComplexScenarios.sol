// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

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
    // Borrow amount is 1000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_1 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_1 =
        [1000000000, 1013141793, 1026456293, 1039945769, 1053612521, 1067458879, 1094454976, 1122133806, 1150512635, 1179609166, 1209441550, 1240028397, 1271388787, 1303542283, 1336508943, 1370309331, 1404964533, 1440496167, 1476926398];

    // Scenario 2: Instant full repayment
    // Borrow amount is 1000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_2 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_2 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    // Scenario 3: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_3 =
        [50000000, 50000000, 50000000, 50000000, 50000000, 50000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_3 =
        [1000000000, 962484704, 924476389, 885968577, 846954703, 807428117, 776583518, 693694354, 608708918, 521574196, 432235832, 340638095, 246723846, 150434501, 51709992, 0];

    // Scenario 4: Half of full amount before default, second half after
    // Borrow amount is 1000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_4 =
        [0, 0, 0, 0, 500000000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_4 =
        [1000000000, 1013141793, 1026456293, 1039945769, 1053612521, 560887982, 575072871, 589616497, 604527932, 619816478, 635491673, 651563294, 668041367, 684936172, 0];

    // Scenario 5: Secondary interest rate is zero
    // Borrow amount is 1000, interest rates are 10% and 0%
    uint256[] public REPAYMENTS_CASE_5 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_5 =
        [1000000000, 1013141793, 1026456293, 1039945769, 1053612521, 1067458879, 1067458879, 1067458879, 1067458879, 1067458879];

    // Scenario 7: Primary interest rate is zero
    // Borrow amount is 1000, interest rates are 0% and 20%
    uint256[] public REPAYMENTS_CASE_6 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_6 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1025290058, 1051219703, 1077805110, 1105062863];

    // Scenario 7: Both primary and secondary interest rates are zero
    // Borrow amount is 1000, interest rates are 0% and 0%
    uint256[] public REPAYMENTS_CASE_7 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_7 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000];

    // Scenario 8: No repayments, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_8 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_8 =
        [1000000000000, 1013141793199, 1026456293127, 1039945769459, 1053612521700, 1067458879572, 1094454976278, 1122133805829, 1150512634577, 1179609165543, 1209441549458, 1240028396084, 1271388785828, 1303542281639, 1336508941216, 1370309329518, 1404964531592, 1440496165727, 1476926396941];

    // Scenario 9: Instant full repayment
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_9 =
        [1000000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_9 =
        [1000000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    // Scenario 10: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_10 =
        [50000000000, 50000000000, 50000000000, 50000000000, 50000000000, 50000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_10 =
        [1000000000000, 962484703539, 924476388810, 885968576669, 846954702825, 807428116719, 776583517529, 693694353757, 608708918247, 521574196165, 432235831930, 340638095305, 246723846631, 150434501185, 51709992632, 0];

    // Scenario 11: Half of full amount before default, second half after
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] public REPAYMENTS_CASE_11 =
        [0, 0, 0, 0, 500000000000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_11 =
        [1000000000000, 1013141793199, 1026456293127, 1039945769459, 1053612521700, 560887982973, 575072872452, 589616498605, 604527933903, 619816480261, 635491674839, 651563295993, 668041369374, 684936174182, 0];

    // Scenario 12: Secondary interest rate is zero
    // Borrow amount is 1000000, interest rates are 10% and 0%
    uint256[] public REPAYMENTS_CASE_12 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_12 =
        [1000000000000, 1013141793199, 1026456293127, 1039945769459, 1053612521700, 1067458879572, 1067458879572, 1067458879572, 1067458879572, 1067458879572];

    // Scenario 13: Primary interest rate is zero
    // Borrow amount is 1000000, interest rates are 0% and 20%
    uint256[] public REPAYMENTS_CASE_13 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_13 =
        [1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1025290057746, 1051219702513, 1077805109493, 1105062862951];

    // Scenario 14: Both primary and secondary interest rates are zero
    // Borrow amount is 1000000, interest rates are 0% and 0%
    uint256[] public REPAYMENTS_CASE_14 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_14 =
        [1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000];

    // Scenario 15: No repayments, both primary & secondary interest rate used
    // Borrow amount is 1000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_15 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_15 =
        [1000000000, 1234331782, 1523574948, 1880596980, 2321280621, 2865230444, 3828782229, 5116368001, 6836957538, 9136166195, 12208578492, 16314216008, 21800543293, 29131874166, 38928667099, 52020035287, 69513915398, 92890833451];

    // Scenario 16: Instant full repayment
    // Borrow amount is 1000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_16 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_16 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    // Scenario 17: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_17 =
        [50000000, 50000000, 50000000, 50000000, 50000000, 50000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_17 =
        [1000000000, 1172615193, 1385679611, 1648671794, 1973291404, 2373979705, 3105513630, 4016241416, 5233238943, 6859502029, 9032663080, 11936639070, 15817196631, 21002751553, 27932162964, 0];

    // Scenario 18: Half of full amount before default, second half after
    // Borrow amount is 1000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_18 =
        [0, 0, 500000000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_18 =
        [1000000000, 1234331782, 1523574948, 1263431089, 1559493147, 1924931955, 2572269633, 3437301276, 4593235448, 6137900110, 8202021906, 10960289698, 0];

    // Scenario 19: Secondary interest rate is zero
    // Borrow amount is 1000, interest rates are 365% and 0%
    uint256[] public REPAYMENTS_CASE_19 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_19 =
        [1000000000, 1234331782, 1523574948, 1880596980, 2321280621, 2865230444, 2865230444, 2865230444, 2865230444, 2865230444];

    // Scenario 20: Primary interest rate is zero
    // Borrow amount is 1000, interest rates are 0% and 730%
    uint256[] public REPAYMENTS_CASE_20 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_20 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1336291200, 1785674172, 2386180683, 3188632249];

    // Scenario 21: Both primary and secondary interest rates are zero
    // Borrow amount is 1000, interest rates are 0% and 0%
    uint256[] public REPAYMENTS_CASE_21 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_21 =
        [1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000, 1000000000];

    // Scenario 22: No repayments, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_22 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_22 =
        [1000000000000, 1234331781587, 1523574947036, 1880596978757, 2321280619237, 2865230442307, 3828782227140, 5116367998331, 6836957534119, 9136166190274, 12208578485351, 16314215999228, 21800543281007, 29131874150100, 38928667077606, 52020035258661, 69513915360052, 92890833400193, 124129203269439];

    // Scenario 23: Instant full repayment
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_23 =
        [1000000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_23 =
        [1000000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

    // Scenario 24: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_24 =
        [50000000000, 50000000000, 50000000000, 50000000000, 50000000000, 50000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, 100000000000, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_24 =
        [1000000000000, 1172615192508, 1385679610605, 1648671793388, 1973291402906, 2373979703861, 3105513628151, 4016241413946, 5233238940053, 6859502025085, 9032663075130, 11936639063332, 15817196622506, 21002751541432, 27932162948724, 0];

    // Scenario 25: Half of full amount before default, second half after
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] public REPAYMENTS_CASE_25 =
        [0, 0, 500000000000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_25 =
        [1000000000000, 1234331781587, 1523574947036, 1263431087963, 1559493145718, 1924931952927, 2572269630043, 3437301271653, 4593235442394, 6137900102984, 8202021896482, 10960289685663, 0];

    // Scenario 26: Secondary interest rate is zero
    // Borrow amount is 1000000, interest rates are 365% and 0%
    uint256[] public REPAYMENTS_CASE_26 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_26 =
        [1000000000000, 1234331781587, 1523574947036, 1880596978757, 2321280619237, 2865230442307, 2865230442307, 2865230442307, 2865230442307, 2865230442307];

    // Scenario 27: Primary interest rate is zero
    // Borrow amount is 1000000, interest rates are 0% and 20%
    uint256[] public REPAYMENTS_CASE_27 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_27 =
        [1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1336291200389, 1785674172236, 2386180683120, 3188632249390];

    // Scenario 28: Both primary and secondary interest rates are zero
    // Borrow amount is 1000000, interest rates are 0% and 0%
    uint256[] public REPAYMENTS_CASE_28 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_28 =
        [1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000, 1000000000000];


    function LOAN_CASE_1() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
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
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
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
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
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
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
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
            repayments : REPAYMENTS_CASE_4,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_4
        });
    }

    function LOAN_CASE_5() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 0,        // 0 %
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
            interestRatePrimary : 0,         // 0 %
            interestRateSecondary : 499635,  // 20 %
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
            interestRatePrimary : 0,     // 0 %
            interestRateSecondary : 0,   // 0 %
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
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_8,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_8
        });
    }

    function LOAN_CASE_9() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_9,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_9
        });
    }

    function LOAN_CASE_10() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_10,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_10
        });
    }

    function LOAN_CASE_11() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 499635,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_11,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_11
        });
    }

    function LOAN_CASE_12() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 261157,     // 10 %
            interestRateSecondary : 0,        // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_12,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_12
        });
    }

    function LOAN_CASE_13() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,          // 0 %
            interestRateSecondary : 499635,   // 20 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_13,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_13
        });
    }

    function LOAN_CASE_14() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,     // 0 %
            interestRateSecondary : 0,   // 0 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_14,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_14
        });
    }

    function LOAN_CASE_15() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
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
            repayments : REPAYMENTS_CASE_15,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_15
        });
    }

    function LOAN_CASE_16() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
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
            repayments : REPAYMENTS_CASE_16,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_16
        });
    }

    function LOAN_CASE_17() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
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
            repayments : REPAYMENTS_CASE_17,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_17
        });
    }

    function LOAN_CASE_18() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
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
            repayments : REPAYMENTS_CASE_18,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_18
        });
    }

    function LOAN_CASE_19() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 0,         // 0 %
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
            repayments : REPAYMENTS_CASE_19,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_19
        });
    }

    function LOAN_CASE_20() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,           // 0 %
            interestRateSecondary : 5814801,   // 730 %
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
            repayments : REPAYMENTS_CASE_20,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_20
        });
    }

    function LOAN_CASE_21() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,     // 0 %
            interestRateSecondary : 0,   // 0 %
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
            repayments : REPAYMENTS_CASE_21,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_21
        });
    }

    function LOAN_CASE_22() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_22,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_22
        });
    }

    function LOAN_CASE_23() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_23,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_23
        });
    }

    function LOAN_CASE_24() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_24,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_24
        });
    }

    function LOAN_CASE_25() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 5814801,   // 730 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_25,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_25
        });
    }

    function LOAN_CASE_26() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 4219472,     // 365 %
            interestRateSecondary : 0,         // 0 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_26,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_26
        });
    }

    function LOAN_CASE_27() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,           // 365 %
            interestRateSecondary : 5814801,   // 730 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_27,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_27
        });
    }

    function LOAN_CASE_28() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 0,     // 0 %
            interestRateSecondary : 0,   // 0 %
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 250,
            interestRateFactor : 1000000000,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000000 * 10 ** 6,
            tokenDecimals : 6,
            step : 50,
            repayments : REPAYMENTS_CASE_28,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_28
        });
    }
}
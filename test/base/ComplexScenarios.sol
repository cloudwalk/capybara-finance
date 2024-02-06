// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";

contract ComplexScenarios is Test {
    struct LoanParameters {
        uint256 interestRatePrimary;
        uint256 interestRateSecondary;
        Interest.Formula interestFormula;
        address addonRecipient;
        uint256 periodInSeconds;
        uint256 durationInPeriods;
        uint256 interestRateFactor;
        uint256 addonPeriodCostRate;
        uint256 addonFixedCostRate;
        uint256 borrowAmount;
        uint8 tokenDecimals;
        uint256[] repayments;
        uint256[] expectedOutstandingBalances;
    }

    // Scenario 1: No repayments
    uint256[] public REPAYMENTS_CASE_1 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_1 =
        [100000, 110000, 121000, 133100, 146410, 161051, 177156, 194872, 214359, 235795, 259374, 285312, 313843, 345227, 379750];

    // Scenario 2: Instant full repayment
    uint256[] public REPAYMENTS_CASE_2 =
        [1000000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_2 =
        [100000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

   // Scenario 3: Partial repayment each period
    uint256[] public REPAYMENTS_CASE_3 =
        [100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000, 100000000];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_3 =
        [100000, 99000, 97900, 96690, 95359, 93895, 92284, 90513, 88564, 86421, 84063, 81469, 78616, 75477, 72025];

    // Scenario 4: Partial repayment each second period
    uint256[] public REPAYMENTS_CASE_4 =
        [100000000, 0, 100000000, 0, 100000000, 0, 100000000, 0, 100000000, 0, 100000000, 0, 100000000, 0, 100000000];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_4 =
        [100000, 99000, 108900, 108790, 119669, 120636, 132699, 134969, 148466, 152313, 167544, 173299, 190629, 198691, 218561];

    // Scenario 5: Partial repayment in first period
    uint256[] public REPAYMENTS_CASE_5 =
        [500000000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_5 =
        [100000, 55000, 60500, 66550, 73205, 80526, 88578, 97436, 107179, 117897, 129687, 142656, 156921, 172614, 189875];

    // Scenario 6: Full repayment during the loan
    uint256[] public REPAYMENTS_CASE_6 =
        [0, 0, 0, 0, 0, 0, 1771560000, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] public EXPECTED_OUTSTANDING_BALANCES_CASE_6 =
        [100000, 110000, 121000, 133100, 146410, 161051, 177156, 0, 0, 0, 0, 0, 0, 0, 0];

    function LOAN_CASE_1() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_1,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_1
        });
}

    function LOAN_CASE_2() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_2,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_2
        });
    }

    function LOAN_CASE_3() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_3,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_3
        });
    }

    function LOAN_CASE_4() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_4,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_4
        });
    }

    function LOAN_CASE_5() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_5,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_5
        });
    }

    function LOAN_CASE_6() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one day
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_6,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_6
        });
    }

    function LOAN_CASE_7() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 1, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_1,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_1
        });
    }

    function LOAN_CASE_8() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 86400, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_2,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_2
        });
    }

    function LOAN_CASE_9() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 1, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_3,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_3
        });
    }

    function LOAN_CASE_10() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 1, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_4,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_4
        });
    }

    function LOAN_CASE_11() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 1, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_5,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_5
        });
    }

    function LOAN_CASE_12() public view returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary : 1,
            interestRateSecondary : 2,
            interestFormula : Interest.Formula.Compound,
            addonRecipient : address(0),
            periodInSeconds : 1, // one second
            durationInPeriods : 15,
            interestRateFactor : 10,
            addonPeriodCostRate : 0,
            addonFixedCostRate : 0,
            borrowAmount : 1000 * 10 ** 6,
            tokenDecimals : 6,
            repayments : REPAYMENTS_CASE_6,
            expectedOutstandingBalances : EXPECTED_OUTSTANDING_BALANCES_CASE_6
        });
    }
}
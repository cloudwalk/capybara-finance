// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";

contract LoanComplexScenarios is Test {
    // -------------------------------------------- //
    //  Constants                                   //
    // -------------------------------------------- //

    uint32 private constant INTEREST_RATE_FACTOR = 1_000_000_000;

    uint32 private constant INTEREST_RATE_365 = 4_219_472; // 365 %
    uint32 private constant INTEREST_RATE_730 = 5_814_801; // 730 %

    uint32 private constant INTEREST_RATE_10 = 261_157; // 10 %
    uint32 private constant INTEREST_RATE_20 = 499_635; // 20 %

    uint64 private constant BORROW_AMOUNT_1B = 1_000_000_000_000;
    uint64 private constant BORROW_AMOUNT_1M = 1_000_000;

    uint32 private constant PERIOD_IN_SECONDS = 86_400;
    uint32 private constant DURATION_IN_PERIODS = 750;
    uint32 private constant ITERATION_STEP = 50;

    uint256 private constant PRECISION_BASE = 10_000_000_000;
    uint256 private constant PRECISION_MINIMUM = 100_000; // 0.01%

    // -------------------------------------------- //
    //  Structs                                     //
    // -------------------------------------------- //

    struct Scenario {
        uint64 borrowAmount;
        uint32 periodInSeconds;
        uint32 durationInPeriods;
        uint32 interestRatePrimary;
        uint32 interestRateSecondary;
        Interest.Formula interestFormula;
        uint32 interestRateFactor;
        uint32 iterationStep;
        uint256 precisionBase;
        uint256 precisionMinimum;
        uint64[] repaymentAmounts;
        uint64[] outstandingBalancesBeforeRepayment;
    }

    // -------------------------------------------- //
    //  Initialization                              //
    // -------------------------------------------- //

    function initScenario(
        uint64 borrowAmount,
        uint32 interestRatePrimary,
        uint32 interestRateSecondary,
        uint64[] memory repaymentAmounts,
        uint64[] memory outstandingBalancesBeforeRepayment
    ) private pure returns (Scenario memory) {
        return Scenario({
            borrowAmount: borrowAmount,
            periodInSeconds: PERIOD_IN_SECONDS,
            durationInPeriods: DURATION_IN_PERIODS,
            interestRatePrimary: interestRatePrimary,
            interestRateSecondary: interestRateSecondary,
            interestFormula: Interest.Formula.Compound,
            interestRateFactor: INTEREST_RATE_FACTOR,
            iterationStep: ITERATION_STEP,
            precisionBase: PRECISION_BASE,
            precisionMinimum: PRECISION_MINIMUM,
            repaymentAmounts: repaymentAmounts,
            outstandingBalancesBeforeRepayment: outstandingBalancesBeforeRepayment
        });
    }


    // -------------------------------------------- //
    //  Loan 10% | 20%, 1M                          //
    // -------------------------------------------- //

    uint64[] private LOAN_10_20_1M_SCENARIO_1_REPAYMENTS = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];

    uint64[] private LOAN_10_20_1M_SCENARIO_1_OUTSTANDING_BALANCES = [
        1013142,
        1026457,
        1039946,
        1053613,
        1067459,
        1081487,
        1095700,
        1110099,
        1124688,
        1139468,
        1154443,
        1169614,
        1184985,
        1200558,
        1216335,
        1247096,
        1278635,
        1310972,
        1344127,
        1378120,
        1412973,
        1448707,
        1485345,
        1522909,
        1561423,
        1600911,
        1641398,
        1682909,
        1725470,
        1769107
    ];

    function LOAN_10_20_1M_SCENARIO_1() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1M,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1M_SCENARIO_1_REPAYMENTS,
            LOAN_10_20_1M_SCENARIO_1_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_10_20_1M_SCENARIO_2_REPAYMENTS = [
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000,
        10000
    ];

    uint64[] private LOAN_10_20_1M_SCENARIO_2_OUTSTANDING_BALANCES = [
        1013142,
        1016325,
        1019550,
        1022817,
        1026127,
        1029481,
        1032879,
        1036321,
        1039809,
        1043343,
        1046923,
        1050550,
        1054225,
        1057948,
        1061720,
        1078318,
        1095336,
        1112784,
        1130673,
        1149015,
        1167821,
        1187102,
        1206871,
        1227140,
        1247922,
        1269229,
        1291075,
        1313473,
        1336438,
        1359984
    ];

    function LOAN_10_20_1M_SCENARIO_2() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1M,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1M_SCENARIO_2_REPAYMENTS,
            LOAN_10_20_1M_SCENARIO_2_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_10_20_1M_SCENARIO_3_REPAYMENTS = [
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000,
        40000
    ];

    uint64[] private LOAN_10_20_1M_SCENARIO_3_OUTSTANDING_BALANCES = [
        1013142,
        985931,
        958362,
        930431,
        902133,
        873463,
        844416,
        814987,
        785172,
        754965,
        724361,
        693355,
        661941,
        630114,
        597869,
        571978,
        545432,
        518214,
        490308,
        461696,
        432361,
        402284,
        371446,
        339828,
        307411,
        274174,
        240096,
        205156,
        169333,
        132604
    ];

    function LOAN_10_20_1M_SCENARIO_3() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1M,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1M_SCENARIO_3_REPAYMENTS,
            LOAN_10_20_1M_SCENARIO_3_OUTSTANDING_BALANCES);
    }

    // -------------------------------------------- //
    //  Loan 10% | 20%, 1B                          //
    // -------------------------------------------- //

    uint64[] private LOAN_10_20_1B_SCENARIO_1_REPAYMENTS = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];

    uint64[] private LOAN_10_20_1B_SCENARIO_1_OUTSTANDING_BALANCES = [
        1013141793199,
        1026456293127,
        1039945769459,
        1053612521700,
        1067458879572,
        1081487203416,
        1095699884591,
        1110099345883,
        1124688041917,
        1139468459577,
        1154443118430,
        1169614571153,
        1184985403970,
        1200558237093,
        1216335725168,
        1247096925896,
        1278636079167,
        1310972859446,
        1344127438765,
        1378120499310,
        1412973246319,
        1448707421312,
        1485345315654,
        1522909784460,
        1561424260851,
        1600912770574,
        1641399946988,
        1682911046432,
        1725471963978,
        1769109249586
    ];

    function LOAN_10_20_1B_SCENARIO_1() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1B,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1B_SCENARIO_1_REPAYMENTS,
            LOAN_10_20_1B_SCENARIO_1_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_10_20_1B_SCENARIO_2_REPAYMENTS = [
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000,
        10000_000000
    ];

    uint64[] private LOAN_10_20_1B_SCENARIO_2_OUTSTANDING_BALANCES = [
        1013141793199,
        1016324875195,
        1019549788596,
        1022817083142,
        1026127315797,
        1029481050845,
        1032878859986,
        1036321322432,
        1039809025007,
        1043342562248,
        1046922536505,
        1050549558043,
        1054224245148,
        1057947224231,
        1061719129936,
        1078317167465,
        1095334970321,
        1112783154394,
        1130672604050,
        1149014478921,
        1167820220867,
        1187101561112,
        1206870527566,
        1227139452323,
        1247920979357,
        1269228072410,
        1291074023077,
        1313472459098,
        1336437352859,
        1359983030110
    ];

    function LOAN_10_20_1B_SCENARIO_2() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1B,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1B_SCENARIO_2_REPAYMENTS,
            LOAN_10_20_1B_SCENARIO_2_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_10_20_1B_SCENARIO_3_REPAYMENTS = [
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000,
        40000_000000
    ];

    uint64[] private LOAN_10_20_1B_SCENARIO_3_OUTSTANDING_BALANCES = [
        1013141793199,
        985930621399,
        958361846006,
        930430767468,
        902132624472,
        873462593133,
        844415786171,
        814987252079,
        785171974278,
        754964870262,
        724360790732,
        693354518717,
        661940768688,
        630114185652,
        597869344244,
        571977892175,
        545431643788,
        518214039246,
        490308099914,
        461696417764,
        432361144521,
        402283980523,
        371446163311,
        339828455921,
        307411134885,
        274173977928,
        240096251352,
        205156697103,
        169333519510,
        132604371687
    ];

    function LOAN_10_20_1B_SCENARIO_3() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1B,
            INTEREST_RATE_10,
            INTEREST_RATE_20,
            LOAN_10_20_1B_SCENARIO_3_REPAYMENTS,
            LOAN_10_20_1B_SCENARIO_3_OUTSTANDING_BALANCES);
    }

    // -------------------------------------------- //
    //  Loan 365% | 730%, 1M                        //
    // -------------------------------------------- //

    uint64[] private LOAN_365_730_1M_SCENARIO_1_REPAYMENTS = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];

    uint64[] private LOAN_365_730_1M_SCENARIO_1_OUTSTANDING_BALANCES = [
        1234332,
        1523575,
        1880597,
        2321281,
        2865231,
        3536646,
        4365395,
        5388346,
        6651007,
        8209549,
        10133307,
        12507863,
        15438853,
        19056667,
        23522250,
        31432576,
        42003075,
        56128340,
        75003807,
        100226927,
        133932361,
        178972635,
        239159557,
        319586812,
        427061045,
        570677916,
        762591877,
        1019044815,
        1361740619,
        1819682006
    ];

    function LOAN_365_730_1M_SCENARIO_1() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1M,
            INTEREST_RATE_365,
            INTEREST_RATE_730,
            LOAN_365_730_1M_SCENARIO_1_REPAYMENTS,
            LOAN_365_730_1M_SCENARIO_1_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_365_730_1M_SCENARIO_2_REPAYMENTS = [
        50000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        1500000,
        1500000,
        1500000,
        1500000,
        1500000,
        1500000,
        1500000,
        1500000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000,
        150000
    ];

    uint64[] private LOAN_365_730_1M_SCENARIO_2_OUTSTANDING_BALANCES = [
        1234332,
        1461859,
        1619269,
        1813565,
        2053391,
        2349416,
        2714809,
        3165825,
        3722529,
        4409686,
        5257866,
        6304801,
        5930719,
        5468977,
        4899034,
        4542099,
        4065130,
        3427761,
        2576050,
        1437916,
        1721031,
        2099355,
        2604906,
        3280469,
        4183218,
        5389554,
        7001570,
        9155693,
        12034228,
        15880789
    ];

    function LOAN_365_730_1M_SCENARIO_2() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1M,
            INTEREST_RATE_365,
            INTEREST_RATE_730,
            LOAN_365_730_1M_SCENARIO_2_REPAYMENTS,
            LOAN_365_730_1M_SCENARIO_2_OUTSTANDING_BALANCES);
    }

    // -------------------------------------------- //
    //  Loan 365% | 730%, 1B                        //
    // -------------------------------------------- //

    uint64[] private LOAN_365_730_1B_SCENARIO_1_REPAYMENTS = [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];

    uint64[] private LOAN_365_730_1B_SCENARIO_1_OUTSTANDING_BALANCES = [
        1234331781587,
        1523574947036,
        1880596978757,
        2321280619237,
        2865230442307,
        3536644996511,
        4365393319385,
        5388343713246,
        6651003895376,
        8209545487524,
        10133302907638,
        12507857831349,
        15438846440811,
        19056658832940,
        23522239648366,
        31432561855543,
        42003055813231,
        56128313872650,
        75003771920670,
        100226880413543,
        133932298339015,
        178972551718242,
        239159445972175,
        319586663142423,
        427060845718765,
        570677650164485,
        762591522173226,
        1019044340571000,
        1361739985110800,
        1819681159320820
    ];

    function LOAN_365_730_1B_SCENARIO_1() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1B,
            INTEREST_RATE_365,
            INTEREST_RATE_730,
            LOAN_365_730_1B_SCENARIO_1_REPAYMENTS,
            LOAN_365_730_1B_SCENARIO_1_OUTSTANDING_BALANCES);
    }

    uint64[] private LOAN_365_730_1B_SCENARIO_2_REPAYMENTS = [
        50000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        1500000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000,
        150000000000
    ];

    uint64[] private LOAN_365_730_1B_SCENARIO_2_OUTSTANDING_BALANCES = [
        1234331781587,
        1461858357957,
        1619268464167,
        1813564761005,
        2053390855237,
        2349415825402,
        2714808854220,
        3165825082460,
        3722528746989,
        4409685773043,
        5257865529243,
        6304800758819,
        5930718280805,
        5468976389258,
        4899033697631,
        4542098819969,
        4065129883837,
        3427760491625,
        2576049381415,
        1437915319568,
        1721029908384,
        2099353442121,
        2604903851153,
        3280466414096,
        4183214722268,
        5389549342644,
        7001563680577,
        9155684255257,
        12034216623778,
        15880774097866
    ];

    function LOAN_365_730_1B_SCENARIO_2() public view returns (Scenario memory) {
        return initScenario(
            BORROW_AMOUNT_1B,
            INTEREST_RATE_365,
            INTEREST_RATE_730,
            LOAN_365_730_1B_SCENARIO_2_REPAYMENTS,
            LOAN_365_730_1B_SCENARIO_2_OUTSTANDING_BALANCES);
    }
}

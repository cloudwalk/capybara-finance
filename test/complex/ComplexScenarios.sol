// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";

contract ComplexScenarios is Test {

    uint32 private constant RATE_10_PERCENT = 261_157; // 10 %
    uint32 private constant RATE_20_PERCENT = 499_635; // 20 %
    uint32 private constant RATE_365_PERCENT = 4_219_472; // 365 %
    uint32 private constant RATE_730_PERCENT = 5_814_801; // 730 %

    struct LoanParameters {
        uint32 interestRatePrimary;
        uint32 interestRateSecondary;
        Interest.Formula interestFormula;
        address addonRecipient;
        uint32 periodInSeconds;
        uint32 durationInPeriods;
        uint32 interestRateFactor;
        uint32 addonPeriodRate;
        uint32 addonFixedRate;
        uint256 borrowAmount;
        uint256 step;
        uint256[] repayments;
        uint256[] outstandingBalances;
    }

    function initLoanParameters(
        uint32 primaryRate,
        uint32 secondaryRate,
        uint256[] memory repayments,
        uint256[] memory outstandingBalances
    ) private pure returns (LoanParameters memory) {
        return LoanParameters({
            interestRatePrimary: primaryRate,
            interestRateSecondary: secondaryRate,
            interestFormula: Interest.Formula.Compound,
            addonRecipient: address(0),
            periodInSeconds: 86_400,
            durationInPeriods: 250,
            interestRateFactor: 1_000_000_000,
            addonPeriodRate: 0,
            addonFixedRate: 0,
            borrowAmount: 1_000_000_000_000,
            step: 50,
            repayments: repayments,
            outstandingBalances: outstandingBalances
        });
    }

    // Scenario 8:
    // - interest rates: 10% and 20%
    // - no repayments
    uint256[] private REPAYMENTS_8 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_8 = [
        1_000_000_000_000,
        1_013_141_793_199,
        1_026_456_293_127,
        1_039_945_769_459,
        1_053_612_521_700,
        1_067_458_879_572,
        1_094_454_976_278,
        1_122_133_805_829,
        1_150_512_634_577,
        1_179_609_165_543,
        1_209_441_549_458,
        1_240_028_396_084,
        1_271_388_785_828,
        1_303_542_281_639,
        1_336_508_941_216,
        1_370_309_329_518,
        1_404_964_531_592,
        1_440_496_165_727,
        1_476_926_396_941
    ];
    function LOAN_CASE_8() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_10_PERCENT, RATE_20_PERCENT, REPAYMENTS_8, OUTSTANDING_BALANCES_8);
    }

    // Scenario 10: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] private REPAYMENTS_10 = [
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        type(uint256).max,
        0
    ];
    uint256[] private OUTSTANDING_BALANCES_10 = [
        1_000_000_000_000,
        962_484_703_539,
        924_476_388_810,
        885_968_576_669,
        846_954_702_825,
        807_428_116_719,
        776_583_517_529,
        693_694_353_757,
        608_708_918_247,
        521_574_196_165,
        432_235_831_930,
        340_638_095_305,
        246_723_846_631,
        150_434_501_185,
        51_709_992_632,
        0
    ];
    function LOAN_CASE_10() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_10_PERCENT, RATE_20_PERCENT, REPAYMENTS_10, OUTSTANDING_BALANCES_10);
    }

    // Scenario 11: Half of full amount before default, second half after
    // Borrow amount is 1000000, interest rates are 10% and 20%
    uint256[] private REPAYMENTS_11 = [0, 0, 0, 0, 500_000_000_000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] private OUTSTANDING_BALANCES_11 = [
        1_000_000_000_000,
        1_013_141_793_199,
        1_026_456_293_127,
        1_039_945_769_459,
        1_053_612_521_700,
        560_887_982_973,
        575_072_872_452,
        589_616_498_605,
        604_527_933_903,
        619_816_480_261,
        635_491_674_839,
        651_563_295_993,
        668_041_369_374,
        684_936_174_182,
        0
    ];
    function LOAN_CASE_11() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_10_PERCENT, RATE_20_PERCENT, REPAYMENTS_11, OUTSTANDING_BALANCES_11);
    }

    // Scenario 12: Secondary interest rate is zero
    // Borrow amount is 1000000, interest rates are 10% and 0%
    uint256[] private REPAYMENTS_12 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_12 = [
        1_000_000_000_000,
        1_013_141_793_199,
        1_026_456_293_127,
        1_039_945_769_459,
        1_053_612_521_700,
        1_067_458_879_572,
        1_067_458_879_572,
        1_067_458_879_572,
        1_067_458_879_572,
        1_067_458_879_572
    ];
    function LOAN_CASE_12() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_10_PERCENT, 0, REPAYMENTS_12, OUTSTANDING_BALANCES_12);
    }

    // Scenario 13: Primary interest rate is zero
    // Borrow amount is 1000000, interest rates are 0% and 20%
    uint256[] private REPAYMENTS_13 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_13 = [
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_025_290_057_746,
        1_051_219_702_513,
        1_077_805_109_493,
        1_105_062_862_951
    ];
    function LOAN_CASE_13() public view returns (LoanParameters memory) {
        return initLoanParameters(0, RATE_20_PERCENT, REPAYMENTS_13, OUTSTANDING_BALANCES_13);
    }

    // Scenario 14: Both primary and secondary interest rates are zero
    // Borrow amount is 1000000, interest rates are 0% and 0%
    uint256[] private REPAYMENTS_14 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_14 = [
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000
    ];
    function LOAN_CASE_14() public view returns (LoanParameters memory) {
        return initLoanParameters(0, 0, REPAYMENTS_14, OUTSTANDING_BALANCES_14);
    }

    // Scenario 22: No repayments, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] private REPAYMENTS_22 =
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_22 = [
        1_000_000_000_000,
        1_234_331_781_587,
        1_523_574_947_036,
        1_880_596_978_757,
        2_321_280_619_237,
        2_865_230_442_307,
        3_828_782_227_140,
        5_116_367_998_331,
        6_836_957_534_119,
        9_136_166_190_274,
        12_208_578_485_351,
        16_314_215_999_228,
        21_800_543_281_007,
        29_131_874_150_100,
        38_928_667_077_606,
        52_020_035_258_661,
        69_513_915_360_052,
        92_890_833_400_193,
        124_129_203_269_439
    ];
    function LOAN_CASE_22() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_365_PERCENT, RATE_730_PERCENT, REPAYMENTS_22, OUTSTANDING_BALANCES_22);
    }

    // Scenario 24: Partial repayment each 50 periods until full repayment, both primary & secondary interest rate used
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] private REPAYMENTS_24 = [
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        50_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        100_000_000_000,
        type(uint256).max,
        0
    ];
    uint256[] private OUTSTANDING_BALANCES_24 = [
        1_000_000_000_000,
        1_172_615_192_508,
        1_385_679_610_605,
        1_648_671_793_388,
        1_973_291_402_906,
        2_373_979_703_861,
        3_105_513_628_151,
        4_016_241_413_946,
        5_233_238_940_053,
        6_859_502_025_085,
        9_032_663_075_130,
        11_936_639_063_332,
        15_817_196_622_506,
        21_002_751_541_432,
        27_932_162_948_724,
        0
    ];
    function LOAN_CASE_24() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_365_PERCENT, RATE_730_PERCENT, REPAYMENTS_24, OUTSTANDING_BALANCES_24);
    }

    // Scenario 25: Half of full amount before default, second half after
    // Borrow amount is 1000000, interest rates are 365% and 730%
    uint256[] private REPAYMENTS_25 = [0, 0, 500_000_000_000, 0, 0, 0, 0, 0, 0, 0, 0, type(uint256).max, 0];
    uint256[] private OUTSTANDING_BALANCES_25 = [
        1_000_000_000_000,
        1_234_331_781_587,
        1_523_574_947_036,
        1_263_431_087_963,
        1_559_493_145_718,
        1_924_931_952_927,
        2_572_269_630_043,
        3_437_301_271_653,
        4_593_235_442_394,
        6_137_900_102_984,
        8_202_021_896_482,
        10_960_289_685_663,
        0
    ];
    function LOAN_CASE_25() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_365_PERCENT, RATE_730_PERCENT, REPAYMENTS_25, OUTSTANDING_BALANCES_25);
    }

    // Scenario 26: Secondary interest rate is zero
    // Borrow amount is 1000000, interest rates are 365% and 0%
    uint256[] private REPAYMENTS_26 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_26 = [
        1_000_000_000_000,
        1_234_331_781_587,
        1_523_574_947_036,
        1_880_596_978_757,
        2_321_280_619_237,
        2_865_230_442_307,
        2_865_230_442_307,
        2_865_230_442_307,
        2_865_230_442_307,
        2_865_230_442_307
    ];
    function LOAN_CASE_26() public view returns (LoanParameters memory) {
        return initLoanParameters(RATE_365_PERCENT, 0, REPAYMENTS_26, OUTSTANDING_BALANCES_26);
    }

    // Scenario 27: Primary interest rate is zero
    // Borrow amount is 1000000, interest rates are 0% and 20%
    uint256[] private REPAYMENTS_27 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_27 = [
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_336_291_200_389,
        1_785_674_172_236,
        2_386_180_683_120,
        3_188_632_249_390
    ];
    function LOAN_CASE_27() public view returns (LoanParameters memory) {
        return initLoanParameters(0, RATE_730_PERCENT, REPAYMENTS_27, OUTSTANDING_BALANCES_27);
    }

    // Scenario 28:
    // - no repayments
    // - borrow amount 1_000_000_000_000
    // - primary interest rate Both primary and secondary interest rates are zero
    // Borrow amount is 1000000, interest rates are 0% and 0%
    uint256[] private REPAYMENTS_28 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    uint256[] private OUTSTANDING_BALANCES_28 = [
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000,
        1_000_000_000_000
    ];
    function LOAN_CASE_28() public view returns (LoanParameters memory) {
        return initLoanParameters(0, 0, REPAYMENTS_28, OUTSTANDING_BALANCES_28);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


import {Loan} from "src/libraries/Loan.sol";
import {Interest} from "src/libraries/Interest.sol";

import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";

import {LendingMarket} from "src/LendingMarket.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "src/pools/LiquidityPoolFactory.sol";
import {ComplexScenarios} from "./ComplexScenarios.sol";

/// @title LendingMarketTest contract
/// @notice Contains complex tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketComplexTest is Test {
    ERC20Mock public token;
    LendingRegistry public registry;
    LendingMarket public lendingMarket;
    CreditLineConfigurable public creditLine;
    LiquidityPoolAccountable public liquidityPool;
    ComplexScenarios public scenarios;

    address public borrower;
    CreditLineConfigurable.CreditLineConfig public creditLineConfig;
    CreditLineConfigurable.BorrowerConfig public borrowerConfig;

    string public constant NAME = "TEST";
    string public constant SYMBOL = "TST";

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant OWNER = address(bytes20(keccak256("owner")));

    uint256 public constant TOKEN_AMOUNT = 100000000000000000000000;
    uint256 public constant CREDITLINE_DEPOSIT_AMOUNT = 10000000000000000;
    uint256 public constant BORROWER_SUPPLY_AMOUNT = 1000000000000;
    uint256 public constant PERMISSIBLE_PERCENT_ERROR = 1;

    uint32 public constant BASE_BLOCKTIMESTAMP = 1337;
    uint256 public constant ZERO_VALUE = 0;

    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant BORROWER = address(bytes20(keccak256("borrower")));
    address public constant LOAN_HOLDER = address(bytes20(keccak256("loan_holder")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint64 public constant CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT = 0;
    uint64 public constant CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT = type(uint64).max;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY = 0;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY = type(uint32).max;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY = 0;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY = type(uint32).max;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS = 0;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS = type(uint32).max;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_COST_RATE = 0;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_COST_RATE = type(uint32).max;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_COST_RATE = 0;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_COST_RATE = type(uint32).max;

    uint32 public constant BORROWER_CONFIG_DURATION = 1000;
    uint64 public constant BORROWER_CONFIG_MIN_BORROW_AMOUNT = 0;
    uint64 public constant BORROWER_CONFIG_MAX_BORROW_AMOUNT = type(uint64).max;
    ICreditLineConfigurable.BorrowPolicy public constant BORROWER_CONFIG_BORROW_POLICY_KEEP =
    ICreditLineConfigurable.BorrowPolicy.Keep;
    Interest.Formula public constant BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND =
    Interest.Formula.Compound;

    bool public constant BORROWER_CONFIG_AUTOREPAYMENT = false;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        //Create LendingMarket
        lendingMarket = new LendingMarket();
        lendingMarket.initialize(NAME, SYMBOL);
        lendingMarket.transferOwnership(OWNER);
        //Create Registry and set it to LendingMarket
        configureRegistry();
        //Deploy complex scenarios contract to use its values
        scenarios = new ComplexScenarios();
        vm.stopPrank();
    }

    function configureRegistry() public {
        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        registry.transferOwnership(OWNER);
        lendingMarket.setRegistry(address(registry));
    }

    function configureLendingMarketForComplexTests(ComplexScenarios.LoanParameters memory loan) public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        //create token
        vm.prank(OWNER);
        configureToken(loan.tokenDecimals);
        //Configure CreditLine
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER, address(token));
        vm.startPrank(LENDER);
        creditLineConfig = createCreditLineConfig(loan);
        creditLine.configureAdmin(ADMIN, true);
        creditLine.configureCreditLine(creditLineConfig);
        vm.stopPrank();
        //Register credit line
        vm.prank(OWNER);
        lendingMarket.registerCreditLine(LENDER, address(creditLine));
        // Supply lender and borrower
        vm.startPrank(OWNER);
        token.transfer(LENDER, TOKEN_AMOUNT);
        token.transfer(BORROWER, TOKEN_AMOUNT);
        vm.stopPrank();
        //Configure Borrower
        vm.startPrank(ADMIN);
        borrowerConfig = createBorrowerConfig(loan);
        borrowerConfig.interestFormula = BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND;
        creditLine.configureBorrower(BORROWER, borrowerConfig);
        vm.stopPrank();
        //configure liquidityPool
        configureLiquidityPool();
        // Increase allowances
        vm.prank(BORROWER);
        token.approve(address(lendingMarket), type(uint256).max);
    }

    function configureToken(uint8 decimals) public {
        token = new ERC20Mock(TOKEN_AMOUNT);
    }

    function configureLiquidityPool() public {
        vm.startPrank(OWNER);
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
        lendingMarket.registerLiquidityPool(LENDER, address(liquidityPool));
        vm.stopPrank();
        vm.startPrank(LENDER);
        lendingMarket.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
        token.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.deposit(address(creditLine), CREDITLINE_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function takeLoan(address borrower, uint256 amount) public returns(uint256) {
        vm.prank(borrower);
        return lendingMarket.takeLoan(address(creditLine), amount);
    }

    function createBorrowerConfig(ComplexScenarios.LoanParameters memory loan) public view returns (ICreditLineConfigurable.BorrowerConfig memory) {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: BASE_BLOCKTIMESTAMP + BORROWER_CONFIG_DURATION,
            minBorrowAmount: BORROWER_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: BORROWER_CONFIG_MAX_BORROW_AMOUNT,
            durationInPeriods: loan.durationInPeriods,
            interestRatePrimary: loan.interestRatePrimary,
            interestRateSecondary: loan.interestRateSecondary,
            addonFixedCostRate: loan.addonFixedCostRate,
            addonPeriodCostRate: loan.addonPeriodCostRate,
            interestFormula: loan.interestFormula,
            borrowPolicy: BORROWER_CONFIG_BORROW_POLICY_KEEP,
            autoRepayment: BORROWER_CONFIG_AUTOREPAYMENT
        });
    }

    function createCreditLineConfig(ComplexScenarios.LoanParameters memory loan) public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            holder: LOAN_HOLDER,
            periodInSeconds: loan.periodInSeconds,
            minDurationInPeriods: CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS,
            minBorrowAmount: CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT,
            minInterestRatePrimary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY,
            interestRateFactor: loan.interestRateFactor,
            addonRecipient: loan.addonRecipient,
            minAddonFixedCostRate: CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_COST_RATE,
            maxAddonFixedCostRate: CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_COST_RATE,
            minAddonPeriodCostRate: CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_COST_RATE,
            maxAddonPeriodCostRate: CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_COST_RATE
        });
    }

    function test_repayLoan_Case1() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_1();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case2() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_2();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case3() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_3();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case4() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_4();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case5() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_5();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case6() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_6();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case7() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_7();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case8() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_8();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case9() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_9();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case10() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_10();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case11() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_11();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case12() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_12();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case13() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_13();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case14() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_14();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case15() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_15();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case16() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_16();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case17() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_17();
        takeLoanAndVerifyCalculations(loan);
    }
        function test_repayLoan_Case18() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_18();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case19() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_19();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case20() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_20();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case21() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_21();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case22() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_22();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case23() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_23();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case24() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_24();
        takeLoanAndVerifyCalculations(loan);
    }
        function test_repayLoan_Case25() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_25();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case26() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_26();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case27() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_27();
        takeLoanAndVerifyCalculations(loan);
    }
    function test_repayLoan_Case28() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_28();
        takeLoanAndVerifyCalculations(loan);
    }
    function takeLoanAndVerifyCalculations(ComplexScenarios.LoanParameters memory loan) public {
        configureLendingMarketForComplexTests(loan);
        uint256 loanId = takeLoan(BORROWER, loan.borrowAmount);
        for (uint256 i = 0; i < loan.expectedOutstandingBalances.length; i++) {
            uint256 contractBalanceWithDecimals = lendingMarket.getLoanPreview(loanId, 0).outstandingBalance;
            (uint256 contractBalance, uint256 expectedBalance) = removeDecimals(loan.tokenDecimals, contractBalanceWithDecimals, loan.expectedOutstandingBalances[i]);
            (uint256 diff, uint256 percent) = getDiff(contractBalance, expectedBalance);
            if (diff == 0) {
                assertEq(contractBalance, expectedBalance);
            } else {
                assertTrue(percent <= PERMISSIBLE_PERCENT_ERROR);
            }
            if (loan.repayments[i] != 0) {
                vm.prank(BORROWER);
                lendingMarket.repayLoan(loanId, loan.repayments[i]);
            }
            skip(loan.periodInSeconds * loan.step);
        }
    }

    function removeDecimals(uint256 tokenDecimals, uint256 contractValue, uint256 expectedValue) public returns (uint256, uint256) {
        uint256 roundedContractValue = contractValue / 10 ** (tokenDecimals - 2);
        uint256 roundedExpectedValue = expectedValue / 10 ** (tokenDecimals - 2);
        return (roundedContractValue, roundedExpectedValue);
    }

    function getDiff(uint256 contractValue, uint256 expectedValue) public pure returns (uint256, uint256) {
        uint256 diff = contractValue > expectedValue ? contractValue - expectedValue : expectedValue - contractValue;
        uint256 percent;

        if (contractValue == 0 && expectedValue == 0) {
            // both values are zero, percentage difference is also zero
            percent = 0;
            return (diff, percent);
        }

        if (contractValue > expectedValue) {
            percent = ((contractValue - expectedValue) * 100) / expectedValue;
        } else {
            percent = ((expectedValue - contractValue) * 100) / expectedValue;
        }
        return (diff, percent);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
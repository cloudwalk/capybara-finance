// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

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
import {ComplexScenarios} from "./base/ComplexScenarios.sol";

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
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    address public constant LIQUIDITY_POOL = address(bytes20(keccak256("liquidity_pool")));

    uint256 public constant TOKEN_AMOUNT = 100000000000000000;
    uint256 public constant CREDITLINE_DEPOSIT_AMOUNT = 10000000000;
    uint256 public constant BORROWER_SUPPLY_AMOUNT = 1000000;

    uint256 public constant BASE_BLOCKTIMESTAMP = 1641070800;
    uint256 public constant ZERO_VALUE = 0;

    address public constant BORROWER = address(bytes20(keccak256("borrower")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint256 public constant INIT_CREDIT_LINE_MIN_BORROW_AMOUNT = 0;
    uint256 public constant INIT_CREDIT_LINE_MAX_BORROW_AMOUNT = type(uint256).max;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY = 0;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY = type(uint256).max;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY = 0;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY = type(uint256).max;

    uint256 public constant INIT_BORROWER_DURATION = 1000;
    uint256 public constant INIT_BORROWER_MIN_BORROW_AMOUNT = 0;
    uint256 public constant INIT_BORROWER_MAX_BORROW_AMOUNT = type(uint256).max;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_PRIMARY = 15;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
    ICreditLineConfigurable.BorrowPolicy.Keep;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA_COMPOUND =
    Interest.Formula.Compound;

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
        borrowerConfig.interestFormula = INIT_BORROWER_INTEREST_FORMULA_COMPOUND;
        creditLine.configureBorrower(BORROWER, borrowerConfig);
        vm.stopPrank();
        //configure liquidityPool
        configureLiquidityPool();
        vm.prank(OWNER);
        lendingMarket.registerLiquidityPool(LENDER, address(liquidityPool));
        // Increase allowances
        vm.prank(BORROWER);
        token.approve(address(lendingMarket), type(uint256).max);
    }

    function configureToken(uint8 decimals) public {
        token = new ERC20Mock(TOKEN_AMOUNT, decimals);
    }

    function configureLiquidityPool() public {
        vm.startPrank(OWNER);
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
        vm.stopPrank();
        vm.startPrank(LENDER);
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
            expiration: block.timestamp + INIT_BORROWER_DURATION,
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: loan.interestRatePrimary,
            interestRateSecondary: loan.interestRateSecondary,
            interestFormula: loan.interestFormula,
            addonRecipient: loan.addonRecipient,
            policy: INIT_BORROWER_POLICY
        });
    }

    function createCreditLineConfig(ComplexScenarios.LoanParameters memory loan) public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            periodInSeconds: loan.periodInSeconds,
            durationInPeriods: loan.durationInPeriods,
            minBorrowAmount: INIT_CREDIT_LINE_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_CREDIT_LINE_MAX_BORROW_AMOUNT,
            interestRateFactor: loan.interestRateFactor,
            minInterestRatePrimary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY,
            addonPeriodCostRate: loan.addonPeriodCostRate,
            addonFixedCostRate: loan.addonFixedCostRate
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
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_10();
        takeLoanAndVerifyCalculations(loan);
    }

    function test_repayLoan_Case12() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_10();
        takeLoanAndVerifyCalculations(loan);
    }

    function takeLoanAndVerifyCalculations(ComplexScenarios.LoanParameters memory loan) public {
        configureLendingMarketForComplexTests(loan);
        uint256 loanId = takeLoan(BORROWER, loan.borrowAmount);
        for(uint256 i = 0; i < loan.expectedOutstandingBalances.length; i++) {
            (uint256 contractBalanceWithDecimals,) = lendingMarket.getLoanBalance(loanId, 0);
            (uint256 contractBalance, uint256 expectedBalance) = removeDecimals(loan.tokenDecimals, contractBalanceWithDecimals, loan.expectedOutstandingBalances[i]);
            assertEq(contractBalance, expectedBalance);
            if(loan.repayments[i] != 0) {
                vm.prank(BORROWER);
                lendingMarket.repayLoan(loanId, loan.repayments[i]);
            }
            skip(loan.periodInSeconds);
        }
    }

    function removeDecimals(uint256 tokenDecimals, uint256 contractValue, uint256 expectedValue) public returns (uint256, uint256) {
        uint256 roundedContractValue = contractValue / 10 ** tokenDecimals;
        uint256 roundedExpectedValue = expectedValue / 10 ** 2; // $ decimal
        return (roundedContractValue, roundedExpectedValue);
    }
}
    // SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Interest } from "src/common/libraries/Interest.sol";

import { ICreditLineConfigurable } from "src/common/interfaces/ICreditLineConfigurable.sol";
import { ERC20Mock } from "src/mocks/ERC20Mock.sol";

import { LendingMarket } from "src/LendingMarket.sol";
import { CreditLineConfigurable } from "src/credit-lines/CreditLineConfigurable.sol";
import { LiquidityPoolAccountable } from "src/liquidity-pools/LiquidityPoolAccountable.sol";
import { ComplexScenarios } from "./ComplexScenarios.sol";

/// @title LendingMarketComplexTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains complex tests for the LendingMarket contract.
contract LendingMarketComplexTest is Test {
    ERC20Mock private token;
    LendingMarket private lendingMarket;
    CreditLineConfigurable private creditLine;
    LiquidityPoolAccountable private liquidityPool;
    ComplexScenarios private scenarios;

    address private borrower;
    CreditLineConfigurable.CreditLineConfig private creditLineConfig;
    CreditLineConfigurable.BorrowerConfig private borrowerConfig;

    address private constant OWNER = address(bytes20(keccak256("owner")));
    address private constant ADMIN = address(bytes20(keccak256("admin")));
    address private constant TOKEN = address(bytes20(keccak256("token")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant BORROWER = address(bytes20(keccak256("borrower")));
    address private constant ADDON_RECIPIENT = address(bytes20(keccak256("recipient")));

    uint256 private constant ZERO_VALUE = 0;
    uint256 private constant PERMISSIBLE_PERCENT_ERROR = 1;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy token
        token = new ERC20Mock();

        // Deploy market
        lendingMarket = new LendingMarket();
        lendingMarket.initialize("NAME", "SYMBOL");

        // Deploy scenarios
        scenarios = new ComplexScenarios();

        // Deploy credit line
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER, address(token));

        // Deploy liquidity pool
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);

        // Register credit line and liquidity pool
        lendingMarket.registerCreditLine(LENDER, address(creditLine));
        lendingMarket.registerLiquidityPool(LENDER, address(liquidityPool));

        vm.stopPrank();

        vm.startPrank(LENDER);

        creditLine.configureAdmin(ADMIN, true);
        lendingMarket.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));

        vm.stopPrank();
    }

    function configureLendingMarketForComplexTests(ComplexScenarios.LoanParameters memory loan) private {
        // Configure token
        vm.startPrank(OWNER);
        token.mint(LENDER, loan.borrowAmount);
        token.mint(BORROWER, type(uint256).max - loan.borrowAmount);
        vm.stopPrank();

        // Configure liquidity pool and credit line
        vm.startPrank(LENDER);
        token.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.deposit(address(creditLine), loan.borrowAmount);
        creditLine.configureCreditLine(createCreditLineConfig(loan));
        vm.stopPrank();

        // Configure borrower
        vm.startPrank(ADMIN);
        creditLine.configureBorrower(BORROWER, createBorrowerConfig(loan));
        vm.stopPrank();

        // Configure allowance
        vm.startPrank(BORROWER);
        token.approve(address(lendingMarket), type(uint256).max);
        vm.stopPrank();
    }

    function takeLoan(address BORROWER_CONFIG_, uint256 amount) private returns (uint256) {
        vm.prank(BORROWER_CONFIG_);
        return lendingMarket.takeLoan(address(creditLine), amount, 250);
    }

    function createBorrowerConfig(ComplexScenarios.LoanParameters memory loan)
        private
        pure
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: type(uint32).max,
            minBorrowAmount: 0,
            maxBorrowAmount: type(uint64).max,
            minDurationInPeriods: 0,
            maxDurationInPeriods: type(uint32).max,
            interestRatePrimary: loan.interestRatePrimary,
            interestRateSecondary: loan.interestRateSecondary,
            addonFixedRate: loan.addonFixedRate,
            addonPeriodRate: loan.addonPeriodRate,
            interestFormula: loan.interestFormula,
            borrowPolicy: ICreditLineConfigurable.BorrowPolicy.Keep,
            autoRepayment: false
        });
    }

    function createCreditLineConfig(ComplexScenarios.LoanParameters memory loan)
        private
        view
        returns (ICreditLineConfigurable.CreditLineConfig memory)
    {
        return ICreditLineConfigurable.CreditLineConfig({
            treasury: address(liquidityPool),
            periodInSeconds: loan.periodInSeconds,
            interestRateFactor: loan.interestRateFactor,
            addonRecipient: loan.addonRecipient,
            minBorrowAmount: 0,
            maxBorrowAmount: type(uint64).max,
            minDurationInPeriods: 0,
            maxDurationInPeriods: type(uint32).max,
            minInterestRatePrimary: 0,
            maxInterestRatePrimary: type(uint32).max,
            minInterestRateSecondary: 0,
            maxInterestRateSecondary: type(uint32).max,
            minAddonFixedRate: 0,
            maxAddonFixedRate: type(uint32).max,
            minAddonPeriodRate: 0,
            maxAddonPeriodRate: type(uint32).max
        });
    }

    // function test_repayLoan_Case8() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_8();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case10() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_10();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    function test_repayLoan_Case11() public {
        ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_11();
        takeLoanAndVerifyCalculations(loan);
    }

    // function test_repayLoan_Case12() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_12();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case13() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_13();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case14() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_14();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case22() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_22();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case24() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_24();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case25() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_25();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case26() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_26();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case27() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_27();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    // function test_repayLoan_Case28() public {
    //     ComplexScenarios.LoanParameters memory loan = scenarios.LOAN_CASE_28();
    //     takeLoanAndVerifyCalculations(loan);
    // }

    function takeLoanAndVerifyCalculations(ComplexScenarios.LoanParameters memory loan) private {
        configureLendingMarketForComplexTests(loan);
        uint256 loanId = takeLoan(BORROWER, loan.borrowAmount);
        for (uint256 i = 0; i < loan.outstandingBalances.length; i++) {
            Loan.Preview memory loanPreview = lendingMarket.getLoanPreview(loanId, 0);

            (uint256 diff, uint256 percent) = getDiff(loanPreview.outstandingBalance, loan.outstandingBalances[i]);
            if (diff == 0) {
                assertEq(loanPreview.outstandingBalance, loan.outstandingBalances[i]);
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

    function getDiff(uint256 contractValue, uint256 expectedValue) private view returns (uint256, uint256) {
        uint256 diff = contractValue > expectedValue ? contractValue - expectedValue : expectedValue - contractValue;
        uint256 percent;

        console.logUint(contractValue);
        console.logUint(expectedValue);
        console.logUint(diff);

        if (contractValue == 0 && expectedValue == 0) {
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
}

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
import { LoanComplexScenarios } from "./LoanComplexScenarios.sol";

/// @title LendingMarketComplexTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains complex tests for the LendingMarket contract.
contract LendingMarketComplexTest is Test {
    ERC20Mock private token;
    LendingMarket private lendingMarket;
    CreditLineConfigurable private creditLine;
    LiquidityPoolAccountable private liquidityPool;
    LoanComplexScenarios private scenarios;

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
    uint256 private constant PERMISSIBLE_ERROR = 1;

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
        scenarios = new LoanComplexScenarios();

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

        // Switch to the lender

        vm.startPrank(LENDER);

        creditLine.configureAdmin(ADMIN, true);
        lendingMarket.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));

        vm.stopPrank();
    }

    function configureScenario(LoanComplexScenarios.Scenario memory scenario) private {
        // Configure token
        vm.startPrank(OWNER);
        token.mint(LENDER, scenario.borrowAmount);
        token.mint(BORROWER, type(uint256).max - scenario.borrowAmount);
        vm.stopPrank();

        // Configure liquidity pool and credit line
        vm.startPrank(LENDER);
        token.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.deposit(address(creditLine), scenario.borrowAmount);
        creditLine.configureCreditLine(createCreditLineConfig(scenario));
        vm.stopPrank();

        // Configure borrower
        vm.startPrank(ADMIN);
        creditLine.configureBorrower(BORROWER, createBorrowerConfig(scenario));
        vm.stopPrank();

        // Configure allowance
        vm.startPrank(BORROWER);
        token.approve(address(lendingMarket), type(uint256).max);
        vm.stopPrank();
    }

    function createBorrowerConfig(LoanComplexScenarios.Scenario memory scenario)
        private
        pure
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: 0,
            maxBorrowAmount: type(uint64).max,
            minDurationInPeriods: 0,
            maxDurationInPeriods: type(uint32).max,
            interestRatePrimary: scenario.interestRatePrimary,
            interestRateSecondary: scenario.interestRateSecondary,
            addonFixedRate: 0,
            addonPeriodRate: 0,
            interestFormula: scenario.interestFormula,
            borrowPolicy: ICreditLineConfigurable.BorrowPolicy.Keep,
            autoRepayment: false,
            expiration: type(uint32).max
        });
    }

    function createCreditLineConfig(LoanComplexScenarios.Scenario memory scenario)
        private
        view
        returns (ICreditLineConfigurable.CreditLineConfig memory)
    {
        return ICreditLineConfigurable.CreditLineConfig({
            treasury: address(liquidityPool),
            periodInSeconds: scenario.periodInSeconds,
            minDurationInPeriods: 0,
            maxDurationInPeriods: type(uint32).max,
            minBorrowAmount: 0,
            maxBorrowAmount: type(uint64).max,
            minInterestRatePrimary: 0,
            maxInterestRatePrimary: type(uint32).max,
            minInterestRateSecondary: 0,
            maxInterestRateSecondary: type(uint32).max,
            interestRateFactor: scenario.interestRateFactor,
            addonRecipient: address(0),
            minAddonFixedRate: 0,
            maxAddonFixedRate: type(uint32).max,
            minAddonPeriodRate: 0,
            maxAddonPeriodRate: type(uint32).max
        });
    }

    // -------------------------------------------- //
    //  Test functions                              //
    // -------------------------------------------- //

    function test_SCENARIO_01_LOAN_10_20_1M() public {
        testScenario(scenarios.SCENARIO_01_LOAN_10_20_1M());
    }

    function test_SCENARIO_02_LOAN_10_20_1M() public {
        testScenario(scenarios.SCENARIO_02_LOAN_10_20_1M());
    }

    function test_SCENARIO_03_LOAN_10_20_1M() public {
        testScenario(scenarios.SCENARIO_03_LOAN_10_20_1M());
    }

    function test_SCENARIO_04_LOAN_10_20_1B() public {
        testScenario(scenarios.SCENARIO_04_LOAN_10_20_1B());
    }

    function test_SCENARIO_05_LOAN_10_20_1B() public {
        testScenario(scenarios.SCENARIO_05_LOAN_10_20_1B());
    }

    function test_SCENARIO_06_LOAN_10_20_1B() public {
        testScenario(scenarios.SCENARIO_06_LOAN_10_20_1B());
    }

    function test_SCENARIO_07_LOAN_365_730_1M() public {
        testScenario(scenarios.SCENARIO_07_LOAN_365_730_1M());
    }

    function test_SCENARIO_08_LOAN_365_730_1M() public {
        testScenario(scenarios.SCENARIO_08_LOAN_365_730_1M());
    }

    function test_SCENARIO_09_LOAN_365_730_1B() public {
        testScenario(scenarios.SCENARIO_09_LOAN_365_730_1B());
    }

    function test_SCENARIO_10_LOAN_365_730_1B() public {
        testScenario(scenarios.SCENARIO_10_LOAN_365_730_1B());
    }

    // -------------------------------------------- //
    //  Helper functions                            //
    // -------------------------------------------- //

    function testScenario(LoanComplexScenarios.Scenario memory scenario) private {
        configureScenario(scenario);

        vm.startPrank(BORROWER);

        uint256 loanId = lendingMarket.takeLoan(address(creditLine), scenario.borrowAmount, scenario.durationInPeriods);

        for (uint256 i = 0; i < scenario.repaymentAmounts.length; i++) {
            skip(scenario.periodInSeconds * scenario.iterationStep);

            Loan.Preview memory previewBefore = lendingMarket.getLoanPreview(loanId, 0);

            if (scenario.repaymentAmounts[i] != 0) {
                lendingMarket.repayLoan(loanId, scenario.repaymentAmounts[i]);
            }

            Loan.Preview memory previewAfter = lendingMarket.getLoanPreview(loanId, 0);

            uint256 difference = diff(previewBefore.outstandingBalance, scenario.outstandingBalancesBeforeRepayment[i]);
            uint256 precision = difference * scenario.precisionFactor / scenario.outstandingBalancesBeforeRepayment[i];

            if (precision > scenario.precisionMinimum) {
                console.log("------------------ Precision error ------------------");
                console.log("Index: ", i);
                console.log("Expected balance before repayment: ", scenario.outstandingBalancesBeforeRepayment[i]);
                console.log("Actual balance before repayment: ", previewBefore.outstandingBalance);
                console.log("Payment amount: ", scenario.repaymentAmounts[i]);
                console.log("Difference: ", difference);
                revert("Precision error");
            }

            require(
                previewAfter.outstandingBalance == previewBefore.outstandingBalance - scenario.repaymentAmounts[i],
                "Outstanding balance mismatch after repayment"
            );
        }
    }

    function diff(uint256 actualValue, uint256 expectedValue) private pure returns (uint256) {
        return actualValue >= expectedValue ? actualValue - expectedValue : expectedValue - actualValue;
    }
}

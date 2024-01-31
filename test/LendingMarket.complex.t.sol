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

/// @title LendingMarketTest contract
/// @notice Contains complex tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketComplexTest is Test {
    ERC20Mock public token;
    LendingRegistry public registry;
    LendingMarket public lendingMarket;
    CreditLineConfigurable public creditLine;
    LiquidityPoolAccountable public liquidityPool;

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

    uint256 public constant TOKEN_AMOUNT = 1000000;
    uint256 public constant CREDITLINE_DEPOSIT_AMOUNT = 10000;
    uint256 public constant BORROWER_LEND_AMOUNT = 100;
    uint256 public constant BORROWER_SUPPLY_AMOUNT = 100000;

    uint256 public constant BASE_BLOCKTIMESTAMP = 1641070800;
    uint256 public constant ZERO_VALUE = 0;

    address public constant BORROWER = address(bytes20(keccak256("borrower")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint256 public constant INIT_CREDIT_LINE_MIN_BORROW_AMOUNT = 50;
    uint256 public constant INIT_CREDIT_LINE_MAX_BORROW_AMOUNT = 1000;
    uint256 public constant INIT_CREDIT_LINE_PERIOD_IN_SECONDS = 86400; // 24 hours
    uint256 public constant INIT_CREDIT_LINE_DURATION_IN_PERIODS = 5; // 5 days
    uint256 public constant INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE = 1;
    uint256 public constant INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE = 1;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY = 10;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY = 20;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY = 10;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY = 20;
    uint256 public constant INIT_CREDIT_LINE_INTEREST_RATE_FACTOR = 5;

    uint256 public constant INIT_BORROWER_DURATION = 1000;
    uint256 public constant INIT_BORROWER_MIN_BORROW_AMOUNT = 50;
    uint256 public constant INIT_BORROWER_MAX_BORROW_AMOUNT = 1000;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_PRIMARY = 15;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_SECONDARY = 20;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA = Interest.Formula.Simple;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
    ICreditLineConfigurable.BorrowPolicy.Keep;

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
        vm.stopPrank();
    }

    function configureRegistry() public {
        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        registry.transferOwnership(OWNER);
        lendingMarket.setRegistry(address(registry));
    }

    function configureLendingMarket() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        //create token
        vm.prank(OWNER);
        configureToken();
        //Configure CreditLine
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER, address(token));
        vm.startPrank(LENDER);
        creditLineConfig = createInitCreditLineConfig();
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
        borrowerConfig = createInitBorrowerConfig();
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

    function configureLendingMarketWithAddonRecipient() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        //create token
        vm.prank(OWNER);
        configureToken();
        //Configure CreditLine
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER, address(token));
        vm.startPrank(LENDER);
        creditLineConfig = createCreditLineConfig();
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
        borrowerConfig = createBorrowerConfig();
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

    function configureToken() public {
        token = new ERC20Mock(TOKEN_AMOUNT);
    }

    function configureLiquidityPool() public {
        vm.startPrank(OWNER);
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
        vm.stopPrank();
        vm.startPrank(LENDER);
        token.approve(address(liquidityPool), TOKEN_AMOUNT);
        liquidityPool.deposit(address(creditLine), CREDITLINE_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function takeLoan(address borrower) public returns(uint256) {
        vm.prank(borrower);
        return lendingMarket.takeLoan(address(creditLine), BORROWER_LEND_AMOUNT);
    }

    function createInitBorrowerConfig() public view returns (ICreditLineConfigurable.BorrowerConfig memory) {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: block.timestamp + INIT_BORROWER_DURATION,
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA,
            addonRecipient: address(0),
            policy: INIT_BORROWER_POLICY
        });
    }

    function createBorrowerConfig() public view returns (ICreditLineConfigurable.BorrowerConfig memory) {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: block.timestamp + INIT_BORROWER_DURATION,
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA,
            addonRecipient: ADDON_RECIPIENT,
            policy: INIT_BORROWER_POLICY
        });
    }

    function createInitCreditLineConfig() public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            periodInSeconds: INIT_CREDIT_LINE_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_CREDIT_LINE_DURATION_IN_PERIODS,
            minBorrowAmount: INIT_CREDIT_LINE_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_CREDIT_LINE_MAX_BORROW_AMOUNT,
            interestRateFactor: INIT_CREDIT_LINE_INTEREST_RATE_FACTOR,
            minInterestRatePrimary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });
    }

    function createCreditLineConfig() public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            periodInSeconds: INIT_CREDIT_LINE_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_CREDIT_LINE_DURATION_IN_PERIODS,
            minBorrowAmount: INIT_CREDIT_LINE_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_CREDIT_LINE_MAX_BORROW_AMOUNT,
            interestRateFactor: INIT_CREDIT_LINE_INTEREST_RATE_FACTOR,
            minInterestRatePrimary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY,
            addonPeriodCostRate: INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE,
            addonFixedCostRate: INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE
        });
    }

    function test_repayBorrow_InstantRepayment() public {
        // In this case interest would be equal to zero because zero periods passed
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 100
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, outstandingBalance);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 0
        assertEq(outstandingBalance, ZERO_VALUE);
    }

    function test_repayBorrow_RepaymentAfterOnePeriod() public {
        // In this case interest would be equal to 300 after one period passed (total repay amount = 400)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 100
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 300
        assertEq(outstandingBalance, 300);
    }

    function test_repayBorrow_RepaymentAfterTwoPeriods() public {
        // In this case interest would be equal to 1500 after two periods passed (total repay amount = 1600)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 2);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 300
        assertEq(outstandingBalance, 1500);
    }

    function test_repayBorrow_RepaymentAfterThreePeriods() public {
        // In this case interest would be equal to 6300 after three periods passed (total repay amount = 6400)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 3);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 6400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 6300
        assertEq(outstandingBalance, 6300);
    }

    function test_repayBorrow_RepaymentAfterFourPeriods() public {
        // In this case interest would be equal to 25500 after four periods passed (total repay amount = 25600)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 4);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 25600
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 25500
        assertEq(outstandingBalance, 25500);
    }

    function test_repayBorrow_RepaymentAfterFivePeriods() public {
        // In this case interest would be equal to 102300 after five periods passed (total repay amount = 102400)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 5);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102300
        assertEq(outstandingBalance, 102300);
    }

    function test_repayBorrow_DefaultedLoanForOnePeriod() public {
        // In this case interest would stop to raise after the loan is defaulted
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * (INIT_CREDIT_LINE_DURATION_IN_PERIODS + 1));
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102300
        assertEq(outstandingBalance, 102300);
    }

    function test_repayBorrow_DefaultedLoanForTenPeriods() public {
        // In this case interest would stop to raise after the loan is defaulted
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * (INIT_CREDIT_LINE_DURATION_IN_PERIODS + 10));
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102300
        assertEq(outstandingBalance, 102300);
    }

    function test_repayLoan_FrozenAfterOnePeriod() public {
        // In this case interest would be equal to 300 after one period passed (total repay amount = 400)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 100
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 300
        assertEq(outstandingBalance, 300);
        vm.stopPrank();
        vm.prank(LENDER);
        lendingMarket.freeze(loanId);
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 300
        assertEq(outstandingBalance, 300);
    }

    function test_repayLoan_DefaultedLoan_RepaymentAfterLoanExpiredForOnePeriod() public {
        // In this case interest would be 511500 after loan is expired for 1 period (total amount is 511600)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * INIT_CREDIT_LINE_DURATION_IN_PERIODS + 1);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102300
        assertEq(outstandingBalance, 102300);
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        // at this moment loan.trackDate should be >= dueDate
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 511400
        assertEq(outstandingBalance, 511400);
    }

    function test_repayLoan_DefaultedLoan_RepaymentAfterLoanExpiredForTwoPeriods() public {
        // In this case interest would be 2557500 after loan is expired for 1 period (total amount is 2557600)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        configureLendingMarket();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * INIT_CREDIT_LINE_DURATION_IN_PERIODS + 1);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102400
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 102300
        assertEq(outstandingBalance, 102300);
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 2);
        // at this moment loan.trackDate should be >= dueDate
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 2557400
        assertEq(outstandingBalance, 2557400);
    }

    function test_repayLoan_AddonRecipient_InstantRepay() public {
        // In this case interest would be equal to zero because zero periods passed
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        uint256 addonAmount = creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT); // 120
        assertEq(outstandingBalance, BORROWER_LEND_AMOUNT + addonAmount);
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 0
        assertEq(outstandingBalance, addonAmount);
    }

    function test_repayLoan_AddonRecipient_RepaymentAfterOnePeriod() public {
        // In this case interest after one period would be 660 (total balance = 880)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 880
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 780
        assertEq(outstandingBalance, 780);
    }

    function test_repayLoan_AddonRecipient_RepaymentAfterTwoPeriods() public {
        // In this case interest after two periods would be 3300 (total balance = 3520)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 2);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 3520
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 3420
        assertEq(outstandingBalance, 3420);
    }

    function test_repayLoan_AddonRecipient_RepaymentAfterThreePeriods() public {
        // In this case interest after three periods would be 13860 (total balance = 14080)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 3);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 14080
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 13980
        assertEq(outstandingBalance, 13980);
    }

    function test_repayLoan_AddonRecipient_RepaymentAfterFourPeriods() public {
        // In this case interest after four periods would be 56100 (total balance = 56320)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 4);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 56320
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 56220
        assertEq(outstandingBalance, 56220);
    }

    function test_repayLoan_AddonRecipient_RepaymentAfterFivePeriods() public {
        // In this case interest after five periods would be 225060 (total balance = 225280)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 5);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225280
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225180
        assertEq(outstandingBalance, 225180);
    }

    function test_repayLoan_AddonRecipient_DefaultedLoanForOnePeriod() public {
        // In this case interest after one period defaulted loan would be 1125900 (total balance = 1126120)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 5);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225280
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225180
        assertEq(outstandingBalance, 225180);
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 1125900
        assertEq(outstandingBalance, 1125900);
    }

    function test_repayLoan_AddonRecipient_DefaultedLoanForTenPeriods() public {
        // In this case interest after one period defaulted loan would be 2199023437380 (total balance = 2199023437720)
        // Borrow amount = 100
        // Interest rate factor = 5
        // Interest rate primary = 15
        // Interest rate secondary = 20
        // Addon amount is 120
        // Addon fixed cost rate = 1
        // Addon period cost rate = 1
        configureLendingMarketWithAddonRecipient();
        uint256 loanId = takeLoan(BORROWER);
        uint256 outstandingBalance;
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 220
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 5);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225280
        vm.startPrank(BORROWER);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 225180
        assertEq(outstandingBalance, 225180);
        skip(INIT_CREDIT_LINE_PERIOD_IN_SECONDS * 10);
        (outstandingBalance,) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE); // 2199023437500
        assertEq(outstandingBalance, 2199023437500);
    }
}
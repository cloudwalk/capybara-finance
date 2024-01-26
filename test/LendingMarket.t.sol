// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Error} from "src/libraries/Error.sol";
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

import {Config} from "./base/Config.sol";

/// @title LendingMarketTest contract
/// @notice Contains tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketTest is Test, Config {

    CreditLineConfigurable public creditLine;

    /************************************************
     *  Events
     ***********************************************/
    event SetRegistry(address indexed newRegistry, address indexed oldRegistry);
    event RegisterCreditLine(address indexed lender, address indexed creditLine);
    event RegisterLiquidityPool(address indexed lender, address indexed liquidityPool);
    event TakeLoan(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);
    event RepayLoan(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );
    event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);
    event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);
    event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
    event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed fromDate, uint256 indexed moratorimPeriods);
    event UpdateLoanInterestRatePrimary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event UpdateLoanInterestRateSecondary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );

    /************************************************
     *  State variables and constants
     ***********************************************/

    ERC20Mock public token;
    LendingRegistry public registry;
    LendingMarket public lendingMarket;

    LiquidityPoolAccountable public liquidityPool;

    address public borrower;
    uint256 public borrowerBlockTimestamp;
    CreditLineConfigurable.CreditLineConfig public creditLineConfig;
    CreditLineConfigurable.BorrowerConfig public borrowerConfig;

    string public constant NAME = "TEST";
    string public constant SYMBOL = "TST";

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address public constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant REGISTRY_1 = address(bytes20(keccak256("registry_1")));
    address public constant CREDIT_LINE_1 = address(bytes20(keccak256("credit_line_1")));
    address public constant CREDIT_LINE_2 = address(bytes20(keccak256("credit_line_2")));
    address public constant LIQUIDITY_POOL_1 = address(bytes20(keccak256("liquidity_pool_1")));
    address public constant LIQUIDITY_POOL_2 = address(bytes20(keccak256("liquidity_pool_2")));

    uint256 public constant NEW_BORROWER_DURATION_IN_PERIODS = 200;
    uint256 public constant NEW_MORATORIUM_PERIODS = 20;
    uint256 public constant NEW_INTEREST_RATE_PRIMARY = 450;
    uint256 public constant NEW_INTEREST_RATE_SECONDARY = 550;

    uint256 public constant TOKEN_AMOUNT = 1000000000;
    uint256 public constant CREDITLINE_DEPOSIT_AMOUNT = 1000000;
    uint256 public constant BORROWER_LEND_AMOUNT = 600;
    uint256 public constant BORROWER_REPAY_AMOUNT = 200;
    uint256 public constant BORROWER_REPAY_BIG_AMOUNT = 100000;

    uint256 public constant BASE_BLOCKTIMESTAMP = 1641070800;
    uint256 public constant INCREASE_BLOCKTIMESTAMP = 1000;
    uint256 public constant ZERO_VALUE = 0;

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
        //create token
        vm.prank(OWNER);
        configureToken();
        //Configure CreditLine
        configureCreditLine();
        vm.prank(OWNER);
        lendingMarket.registerCreditLine(LENDER_1, address(creditLine));
        vm.prank(OWNER);
        token.transfer(LENDER_1, TOKEN_AMOUNT);
        //Configure Borrower
        configureBorrower();
        //configure liquidityPool
        configureLiquidityPool();
        vm.prank(OWNER);
        lendingMarket.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function configureToken() public {
        token = new ERC20Mock(TOKEN_AMOUNT);
    }

    function configureCreditLine() public {
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER_1, address(token));
        vm.startPrank(LENDER_1);
        creditLineConfig = initCreditLineConfig();
        creditLine.configureAdmin(ADMIN, true);
        creditLine.configureCreditLine(creditLineConfig);
        vm.stopPrank();
    }

    function configureBorrower() public {
        vm.startPrank(ADMIN);
        borrowerBlockTimestamp = block.timestamp;
        borrowerConfig = initBorrowerConfig(borrowerBlockTimestamp);
        borrowerConfig.interestFormula = INIT_BORROWER_INTEREST_FORMULA_COMPOUND;
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
        vm.stopPrank();
    }

    function configureLiquidityPool() public {
        vm.startPrank(OWNER);
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER_1);
        vm.stopPrank();
        vm.startPrank(LENDER_1);
        token.approve(address(liquidityPool), TOKEN_AMOUNT);
        liquidityPool.deposit(address(creditLine), CREDITLINE_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function takeLoan() public returns(uint256) {
        vm.prank(BORROWER_1);
        return lendingMarket.takeLoan(address(creditLine), BORROWER_LEND_AMOUNT);
    }

    /************************************************
     *  Test `initialize` function
     ***********************************************/

    function test_initialize() public {
        lendingMarket = new LendingMarket();
        lendingMarket.initialize(NAME, SYMBOL);
        assertEq(lendingMarket.name(), NAME);
        assertEq(lendingMarket.symbol(), SYMBOL);

        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        assertEq(registry.market(), address(lendingMarket));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        lendingMarket = new LendingMarket();
        lendingMarket.initialize(NAME, SYMBOL);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        lendingMarket.initialize(NAME, SYMBOL);
    }

    /************************************************
     *  Test `pause` function
     ***********************************************/

    function test_pause() public {
        assertEq(lendingMarket.paused(), false);
        vm.prank(OWNER);
        lendingMarket.pause();
        assertEq(lendingMarket.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        lendingMarket.pause();
        assertEq(lendingMarket.paused(), true);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.pause();
        vm.stopPrank();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        lendingMarket.pause();
    }

    /************************************************
     *  Test `unpause` function
     ***********************************************/

    function test_unpause() public {
        vm.startPrank(OWNER);
        assertEq(lendingMarket.paused(), false);
        lendingMarket.pause();
        assertEq(lendingMarket.paused(), true);
        lendingMarket.unpause();
        assertEq(lendingMarket.paused(), false);
        vm.stopPrank();
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(lendingMarket.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        lendingMarket.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        lendingMarket.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        lendingMarket.unpause();
    }

    /************************************************
     *  Test `setRegistry\registry` functions
     ***********************************************/

    function test_setRegistry() public {
        vm.startPrank(OWNER);
        assertEq(lendingMarket.registry(), address(registry));

        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit SetRegistry(REGISTRY_1, address(registry));
        lendingMarket.setRegistry(REGISTRY_1);
        assertEq(lendingMarket.registry(), REGISTRY_1);

        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit SetRegistry(address(0), REGISTRY_1);
        lendingMarket.setRegistry(address(0));
        assertEq(lendingMarket.registry(), address(0));
        vm.stopPrank();
    }

    function test_setRegistry_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        lendingMarket.setRegistry(REGISTRY_1);
    }

    function test_setRegistry_Revert_IfSetTheSameRegistry() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        lendingMarket.setRegistry(address(registry));
    }

    /************************************************
     *  Test `registerCreditLine` function
     ***********************************************/

    function test_registerCreditLine() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterCreditLine(LENDER_1, CREDIT_LINE_1);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_1);

        vm.prank(address(registry));
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterCreditLine(LENDER_1, CREDIT_LINE_2);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_2);
    }

    function test_registerCreditLine_Revert_IfPaused() public {
        vm.prank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_1);
    }

    function test_registerCreditLine_Revert_IfCallerNotOwnerAndNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_1);
    }

    function test_registerCreditLine_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        lendingMarket.registerCreditLine(address(0), CREDIT_LINE_1);
    }

    function test_registerCreditLine_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        lendingMarket.registerCreditLine(LENDER_1, address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineAlreadyRegistered() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterCreditLine(LENDER_1, CREDIT_LINE_1);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_1);

        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        lendingMarket.registerCreditLine(LENDER_1, CREDIT_LINE_1);
    }

    /************************************************
     *  Test `registerLiquidityPool` function
     ***********************************************/

    function test_registerLiquidityPool() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);
        lendingMarket.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);

        vm.prank(address(registry));
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterLiquidityPool(LENDER_2, LIQUIDITY_POOL_1);
        lendingMarket.registerLiquidityPool(LENDER_2, LIQUIDITY_POOL_1);
    }

    function test_registerLiquidityPool_Revert_IfPaused() public {
        vm.prank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);
    }

    function test_registerLiquidityPool_Revert_IfCallerNotOwnerAndNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);
    }

    function test_registerLiquidityPool_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        lendingMarket.registerLiquidityPool(address(0), LIQUIDITY_POOL_1);
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        lendingMarket.registerLiquidityPool(LENDER_1, address(0));
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolForLenderRegistered() public {
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);
        lendingMarket.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);

        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        lendingMarket.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL_1);
    }

    /************************************************
     *  Test `takeLoan` function
     ***********************************************/

    function test_takeLoan() public {
        configureLendingMarket();
        uint256 addonRate = creditLineConfig.addonFixedCostRate + creditLineConfig.addonPeriodCostRate * creditLineConfig.durationInPeriods;
        uint256 calculatedAddonAmount = (BORROWER_LEND_AMOUNT * addonRate) / creditLineConfig.interestRateFactor;

        vm.prank(BORROWER_1);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit TakeLoan(ZERO_VALUE, BORROWER_1, BORROWER_LEND_AMOUNT + calculatedAddonAmount);

        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROWER_LEND_AMOUNT);
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(token.balanceOf(BORROWER_1), BORROWER_LEND_AMOUNT);
        assertEq(
            token.balanceOf(ADDON_RECIPIENT),
            creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT));
        assertEq(token.balanceOf(
            address(liquidityPool)),
            CREDITLINE_DEPOSIT_AMOUNT -
            BORROWER_LEND_AMOUNT -
            creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT)
        );

        assertEq(loan.borrower, BORROWER_1);
        assertEq(loan.token, address(token));
        assertEq(loan.periodInSeconds, INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        assertEq(loan.durationInPeriods, INIT_CREDIT_LINE_DURATION_IN_PERIODS);
        assertEq(loan.interestRateFactor, INIT_CREDIT_LINE_INTEREST_RATE_FACTOR);
        assertEq(loan.interestRatePrimary, INIT_BORROWER_INTEREST_RATE_PRIMARY);
        assertEq(loan.interestRateSecondary, INIT_BORROWER_INTEREST_RATE_SECONDARY);
        assertTrue(loan.interestFormula == INIT_BORROWER_INTEREST_FORMULA_COMPOUND);
        assertEq(loan.initialBorrowAmount,
            BORROWER_LEND_AMOUNT + creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT));
        assertEq(loan.trackedBorrowAmount,
            BORROWER_LEND_AMOUNT + creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT));
        assertEq(loan.startDate,
            lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE));
        assertEq(loan.trackDate,
            lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE));
        assertEq(loan.freezeDate, ZERO_VALUE);
    }

    function test_takeLoan_Revert_IfPaused() public {
        vm.prank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.takeLoan(address(creditLine), BORROWER_LEND_AMOUNT);
    }

    function test_takeLoan_Revert_IfCreditLineAddressIsZero() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        lendingMarket.takeLoan(address(0), BORROWER_LEND_AMOUNT);
    }

    function test_takeLoan_Revert_IfAmountIsZero() public {
        configureLendingMarket();
        vm.prank(OWNER);
        vm.expectRevert(Error.InvalidAmount.selector);
        lendingMarket.takeLoan(address(creditLine), ZERO_VALUE);
    }

    function test_takeLoan_Revert_IfCreditLineNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        lendingMarket.takeLoan(address(CREDIT_LINE_1), BORROWER_LEND_AMOUNT);
    }

    function test_takeLoan_Revert_IfLiquidityPoolNotExist() public {
        configureToken();
        configureCreditLine();
        vm.prank(OWNER);
        lendingMarket.registerCreditLine(LENDER_1, address(creditLine));
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        lendingMarket.takeLoan(address(creditLine), BORROWER_LEND_AMOUNT);
    }

    /************************************************
     *  Test `repayLoan` function
     ***********************************************/

    function test_repayLoan() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        uint256 addonRecipientAmount = creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT);

        vm.startPrank(BORROWER_1);
        token.approve(address(lendingMarket), TOKEN_AMOUNT);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RepayLoan(
            loanId, BORROWER_1,
            loan.borrower,
            BORROWER_REPAY_AMOUNT,
            outstandingBalance - BORROWER_REPAY_AMOUNT
        );
        lendingMarket.repayLoan(loanId, BORROWER_REPAY_AMOUNT);
        vm.stopPrank();

        Loan.State memory loanRepaid = lendingMarket.getLoan(loanId);
        uint256 currentDate = lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE);

        assertEq(token.balanceOf(BORROWER_1), BORROWER_LEND_AMOUNT - BORROWER_REPAY_AMOUNT);
        assertEq(token.balanceOf(ADDON_RECIPIENT), addonRecipientAmount);
        assertEq(
            token.balanceOf(address(liquidityPool)),
            CREDITLINE_DEPOSIT_AMOUNT - BORROWER_LEND_AMOUNT - addonRecipientAmount + BORROWER_REPAY_AMOUNT);

        assertEq(loanRepaid.borrower, BORROWER_1);
        assertEq(loanRepaid.token, address(token));
        assertEq(loanRepaid.periodInSeconds, INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        assertEq(loanRepaid.durationInPeriods, INIT_CREDIT_LINE_DURATION_IN_PERIODS);
        assertEq(loanRepaid.interestRateFactor, INIT_CREDIT_LINE_INTEREST_RATE_FACTOR);
        assertEq(loanRepaid.interestRatePrimary, INIT_BORROWER_INTEREST_RATE_PRIMARY);
        assertEq(loanRepaid.interestRateSecondary, INIT_BORROWER_INTEREST_RATE_SECONDARY);
        assertTrue(loanRepaid.interestFormula == INIT_BORROWER_INTEREST_FORMULA_COMPOUND);
        assertEq(loanRepaid.initialBorrowAmount, BORROWER_LEND_AMOUNT + addonRecipientAmount);
        assertEq(loanRepaid.trackedBorrowAmount, outstandingBalance - BORROWER_REPAY_AMOUNT);
        assertEq(loanRepaid.startDate,
            lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE));
        assertEq(loanRepaid.trackDate, currentDate);
        assertEq(loanRepaid.freezeDate, ZERO_VALUE);
    }

    function test_repayLoan_Uint256Max() public {
        configureLendingMarket();
        vm.prank(OWNER);
        token.transfer(BORROWER_1, BORROWER_REPAY_BIG_AMOUNT);
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        uint256 addonRecipientAmount = creditLine.calculateAddonAmount(BORROWER_LEND_AMOUNT);

        vm.startPrank(BORROWER_1);
        token.approve(address(lendingMarket), type(uint256).max);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RepayLoan(
            loanId, BORROWER_1,
            loan.borrower,
            outstandingBalance,
            ZERO_VALUE
        );
        lendingMarket.repayLoan(loanId, type(uint256).max);
        vm.stopPrank();

        Loan.State memory loanRepaid = lendingMarket.getLoan(loanId);

        assertEq(loanRepaid.borrower, BORROWER_1);
        assertEq(loanRepaid.token, address(token));
        assertEq(loanRepaid.periodInSeconds, INIT_CREDIT_LINE_PERIOD_IN_SECONDS);
        assertEq(loanRepaid.durationInPeriods, INIT_CREDIT_LINE_DURATION_IN_PERIODS);
        assertEq(loanRepaid.interestRateFactor, INIT_CREDIT_LINE_INTEREST_RATE_FACTOR);
        assertEq(loanRepaid.interestRatePrimary, INIT_BORROWER_INTEREST_RATE_PRIMARY);
        assertEq(loanRepaid.interestRateSecondary, INIT_BORROWER_INTEREST_RATE_SECONDARY);
        assertTrue(loanRepaid.interestFormula == INIT_BORROWER_INTEREST_FORMULA_COMPOUND);
        assertEq(loanRepaid.initialBorrowAmount, BORROWER_LEND_AMOUNT + addonRecipientAmount);
        assertEq(loanRepaid.trackedBorrowAmount, ZERO_VALUE);
        assertEq(loanRepaid.startDate,
            lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE));
        assertEq(loanRepaid.freezeDate, ZERO_VALUE);
    }

    function test_repayLoan_Revert_IfPaused() public {
        vm.prank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.repayLoan(ZERO_VALUE, BORROWER_LEND_AMOUNT);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.repayLoan(ZERO_VALUE, BORROWER_LEND_AMOUNT);
    }

    function test_repayLoan_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);
        Loan.State memory loanRepaid = lendingMarket.getLoan(loanId);

        assertEq(loanRepaid.trackedBorrowAmount, ZERO_VALUE);

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.repayLoan(loanId, BORROWER_LEND_AMOUNT);
    }

    function test_repayLoan_Revert_IfAmountIsZero() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        lendingMarket.repayLoan(loanId, ZERO_VALUE);
    }

    function test_repayLoan_Revert_IfAmountGreaterThanOutstandingBalance() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        lendingMarket.repayLoan(loanId, outstandingBalance + BORROWER_REPAY_AMOUNT);
    }

    /************************************************
     *  Test `freeze` function
     ***********************************************/

    function test_freeze() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.freezeDate, ZERO_VALUE);

        vm.startPrank(LENDER_1);
        uint256 freezeDate = lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit FreezeLoan(loanId, freezeDate);
        lendingMarket.freeze(loanId);

        Loan.State memory loanFreezed = lendingMarket.getLoan(loanId);
        assertEq(loanFreezed.freezeDate, freezeDate);
        vm.stopPrank();
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.freezeDate, ZERO_VALUE);

        vm.startPrank(LENDER_1);
        uint256 freezeDate = lendingMarket.calculatePeriodDate(block.timestamp+1, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit FreezeLoan(loanId, freezeDate);
        lendingMarket.freeze(loanId);

        console.log(freezeDate);

        Loan.State memory loanFreezed = lendingMarket.getLoan(loanId);
        assertEq(loanFreezed.freezeDate, freezeDate);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        lendingMarket.freeze(loanId);
        vm.stopPrank();
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.freeze(loanId);
        vm.stopPrank();
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.freeze(ZERO_VALUE);
    }

    function test_freeze_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.freeze(loanId);
    }

    /************************************************
     *  Test `unfreeze` function
     ***********************************************/

    function test_unfreeze() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        vm.startPrank(LENDER_1);
        uint256 freezeDate = lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE);
        lendingMarket.freeze(loanId);

        assertEq(loan.periodInSeconds, INIT_CREDIT_LINE_PERIOD_IN_SECONDS);

        vm.warp(BASE_BLOCKTIMESTAMP + INCREASE_BLOCKTIMESTAMP);
        uint256 currentDate = lendingMarket.calculatePeriodDate(block.timestamp, loan.periodInSeconds, ZERO_VALUE, ZERO_VALUE);

        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit UnfreezeLoan(loanId, currentDate);
        lendingMarket.unfreeze(loanId);

        Loan.State memory loanUnfrozen = lendingMarket.getLoan(loanId);
        assertEq(loanUnfrozen.freezeDate, ZERO_VALUE);
        vm.stopPrank();
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.unfreeze(ZERO_VALUE);
    }

    function test_unfreeze_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        lendingMarket.unfreeze(loanId);
    }

    /************************************************
     *  Test `updateLoanDuration` function
     ***********************************************/

    function test_updateLoanDuration() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.durationInPeriods, INIT_CREDIT_LINE_DURATION_IN_PERIODS);

        vm.startPrank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit UpdateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS, loan.durationInPeriods);
        lendingMarket.updateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS);

        Loan.State memory loanUpdated = lendingMarket.getLoan(loanId);
        assertEq(loanUpdated.durationInPeriods, NEW_BORROWER_DURATION_IN_PERIODS);

        lendingMarket.updateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS + 1);
        loanUpdated = lendingMarket.getLoan(loanId);
        assertEq(loanUpdated.durationInPeriods, NEW_BORROWER_DURATION_IN_PERIODS + 1);
        vm.stopPrank();
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.updateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.updateLoanDuration(ZERO_VALUE, NEW_BORROWER_DURATION_IN_PERIODS);
    }

    function test_updateLoanDuration_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.updateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS);
    }

    function test_updateLoanDuration_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.updateLoanDuration(loanId, NEW_BORROWER_DURATION_IN_PERIODS);
    }

    function test_updateLoanDuration_Revert_IfInappropriateLoanDuration() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        lendingMarket.updateLoanDuration(loanId, INIT_CREDIT_LINE_DURATION_IN_PERIODS);
    }

    /************************************************
     *  Test `updateLoanMoratorium` function
     ***********************************************/

    function test_updateLoanMoratorium() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.durationInPeriods, INIT_CREDIT_LINE_DURATION_IN_PERIODS);

        vm.startPrank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit UpdateLoanMoratorium(loanId, loan.trackDate, NEW_MORATORIUM_PERIODS);
        lendingMarket.updateLoanMoratorium(loanId, NEW_MORATORIUM_PERIODS);

        Loan.State memory loanUpdated = lendingMarket.getLoan(loanId);
        assertEq(loanUpdated.trackDate, loan.trackDate + NEW_MORATORIUM_PERIODS * loan.periodInSeconds);
        vm.stopPrank();
    }

    function test_updateLoanMoratorium_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.updateLoanMoratorium(loanId, NEW_MORATORIUM_PERIODS);
    }

    function test_updateLoanMoratorium_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.updateLoanMoratorium(ZERO_VALUE, NEW_MORATORIUM_PERIODS);
    }

    function test_updateLoanMoratorium_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.updateLoanMoratorium(loanId, NEW_MORATORIUM_PERIODS);
    }

    function test_updateLoanMoratorium_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.updateLoanMoratorium(loanId, NEW_MORATORIUM_PERIODS);
    }

    function test_updateLoanMoratorium_Revert_IfInappropriateLoanMoratorium() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        lendingMarket.updateLoanMoratorium(loanId, ZERO_VALUE);
    }

    /************************************************
     *  Test `updateLoanInterestRatePrimary` function
     ***********************************************/

    function test_updateLoanInterestRatePrimary() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.interestRatePrimary, INIT_BORROWER_INTEREST_RATE_PRIMARY);

        vm.startPrank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit UpdateLoanInterestRatePrimary(loanId, NEW_INTEREST_RATE_PRIMARY, loan.interestRatePrimary);
        lendingMarket.updateLoanInterestRatePrimary(loanId, NEW_INTEREST_RATE_PRIMARY);

        Loan.State memory loanUpdated = lendingMarket.getLoan(loanId);
        assertEq(loanUpdated.interestRatePrimary, NEW_INTEREST_RATE_PRIMARY);
        vm.stopPrank();
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.updateLoanInterestRatePrimary(loanId, NEW_INTEREST_RATE_PRIMARY);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.updateLoanInterestRatePrimary(ZERO_VALUE, NEW_INTEREST_RATE_PRIMARY);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.updateLoanInterestRatePrimary(loanId, NEW_INTEREST_RATE_PRIMARY);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.updateLoanInterestRatePrimary(loanId, NEW_INTEREST_RATE_PRIMARY);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfInappropriateInterestRate() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        lendingMarket.updateLoanInterestRatePrimary(loanId, loan.interestRatePrimary++);
    }

    /************************************************
     *  Test `updateLoanInterestRateSecondary` function
     ***********************************************/

    function test_updateLoanInterestRateSecondary() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        assertEq(loan.interestRateSecondary, INIT_BORROWER_INTEREST_RATE_SECONDARY);

        vm.startPrank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit UpdateLoanInterestRateSecondary(loanId, NEW_INTEREST_RATE_SECONDARY, loan.interestRateSecondary);
        lendingMarket.updateLoanInterestRateSecondary(loanId, NEW_INTEREST_RATE_SECONDARY);

        Loan.State memory loanUpdated = lendingMarket.getLoan(loanId);
        assertEq(loanUpdated.interestRateSecondary, NEW_INTEREST_RATE_SECONDARY);
        vm.stopPrank();
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.startPrank(OWNER);
        lendingMarket.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.updateLoanInterestRateSecondary(loanId, NEW_INTEREST_RATE_SECONDARY);
        vm.stopPrank();
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        lendingMarket.updateLoanInterestRateSecondary(ZERO_VALUE, NEW_INTEREST_RATE_SECONDARY);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanAlreadyRepaid() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        uint256 outstandingBalance = loan.trackedBorrowAmount;
        vm.prank(BORROWER_1);
        token.approve(address(lendingMarket), outstandingBalance);
        vm.prank(LENDER_1);
        token.transfer(BORROWER_1, outstandingBalance);
        vm.prank(BORROWER_1);
        lendingMarket.repayLoan(loanId, outstandingBalance);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        lendingMarket.updateLoanInterestRateSecondary(loanId, NEW_INTEREST_RATE_SECONDARY);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanHolderIsWrong() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        lendingMarket.updateLoanInterestRateSecondary(loanId, NEW_INTEREST_RATE_SECONDARY);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfInappropriateInterestRate() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        lendingMarket.updateLoanInterestRateSecondary(loanId, loan.interestRateSecondary++);
    }

    /************************************************
     *  Test `updateLender` function
     ***********************************************/

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarket.updateLender(address(creditLine), OWNER);
    }

    /************************************************
     *  Test `getLender` function
     ***********************************************/

    function test_getLender() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        assertEq(lendingMarket.getLender(address(creditLine)), LENDER_1);
    }

    /************************************************
     *  Test `getLiquidityPool` function
     ***********************************************/

    function test_getLiquidityPool() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        assertEq(lendingMarket.getLiquidityPool(LENDER_1), address(liquidityPool));
    }

    /************************************************
     *  Test `getLoan` function
     ***********************************************/

    function test_getLoan() public {
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);
        assertEq(loan.token, address(token));
    }

    /************************************************
     *  Test `getLoanBalance` function
     ***********************************************/

    function test_getLoanBalance() public {
        vm.warp(BASE_BLOCKTIMESTAMP);
        configureLendingMarket();
        uint256 loanId = takeLoan();
        Loan.State memory loan = lendingMarket.getLoan(loanId);

        uint256 currentTime = block.timestamp;

        (uint256 balance, uint256 timestamp) = lendingMarket.getLoanBalance(loanId, currentTime);
        assertEq(balance, loan.trackedBorrowAmount);
        assertEq(timestamp, currentTime);

        (balance, timestamp) = lendingMarket.getLoanBalance(loanId, ZERO_VALUE);
        currentTime = block.timestamp;
        assertEq(balance, loan.trackedBorrowAmount);
        assertEq(timestamp, currentTime);
    }

    function calculatePeriodDate(uint256 periodInSeconds, uint256 extraPeriods, uint256 extraSeconds)
        public
        view
        returns (uint256)
    {
        return (block.timestamp / periodInSeconds) * periodInSeconds + periodInSeconds * extraPeriods + extraSeconds;
    }
}

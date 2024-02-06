// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LendingMarket} from "src/LendingMarket.sol";
import {CreditLineMock} from "src/mocks/CreditLineMock.sol";
import {LiquidityPoolMock} from "src/mocks/LiquidityPoolMock.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {Config} from "test/base/Config.sol";

/// @title LendingMarketTest contract
/// @notice Contains tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketTest is Test, Config {
    /************************************************
     *  Events
     ***********************************************/

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event FreezeLoan(uint256 indexed loanId, uint256 freezeDate);
    event UnfreezeLoan(uint256 indexed loanId, uint256 unfreezeDate);

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
    event UpdateLoanDuration(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
    event UpdateLoanMoratorium(uint256 indexed loanId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
    event UpdateLoanInterestRatePrimary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event UpdateLoanInterestRateSecondary(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event SetRegistry(address indexed newRegistry, address indexed oldRegistry);

    /************************************************
     *  Storage variables
     ***********************************************/

    ERC20Mock public token;
    LendingMarket public market;
    CreditLineMock public creditLine;
    LiquidityPoolMock public liquidityPool;

    uint256 public constant NONEXISTENT_LOAN_ID = 9999999;
    uint256 public constant INIT_BLOCK_TIMESTAMP = INIT_CREDIT_LINE_PERIOD_IN_SECONDS + 1;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        token = new ERC20Mock(0);
        creditLine = new CreditLineMock();
        liquidityPool = new LiquidityPoolMock();

        market = new LendingMarket();
        market.initialize("NAME", "SYMBOL");
        market.setRegistry(REGISTRY);
        market.transferOwnership(OWNER);

        skip(INIT_BLOCK_TIMESTAMP);
    }

    function configureMarket() internal {
        vm.startPrank(REGISTRY);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.stopPrank();
        vm.prank(address(liquidityPool));
        token.approve(address(market), type(uint256).max);
    }

    function mockLoanTerms(bool autoRepayment) internal returns (uint256, Loan.Terms memory) {
        Loan.Terms memory terms = initLoanTerms(address(token));
        terms.autoRepayment = autoRepayment;
        creditLine.mockLoanTerms(BORROWER_1, BORROW_AMOUNT, terms);
        return (BORROW_AMOUNT, terms);
    }

    function createActiveLoan(bool autoRepayment) internal returns (uint256 loanId) {
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms(autoRepayment);
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        vm.prank(BORROWER_1);
        loanId = market.takeLoan(address(creditLine), borrowAmount);

        // TODO Validate loan status

        return loanId;
    }

    function createRepaidLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        skip(loan.durationInPeriods * loan.periodInSeconds / 2);

        uint256 originalBalance = loan.trackedBorrowAmount;
        uint256 numberOfPeriods = loan.durationInPeriods / 2;
        uint256 interestRate = loan.interestRatePrimary;
        uint256 interestRateFactor = loan.interestRateFactor;
        Interest.Formula interestFormula = loan.interestFormula;

        uint256 outstandingBalance = market.calculateOutstandingBalance(
            originalBalance, numberOfPeriods, interestRate, interestRateFactor, interestFormula
        );

        token.mint(BORROWER_1, outstandingBalance);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), outstandingBalance);
        market.repayLoan(loanId, outstandingBalance);
        vm.stopPrank();

        // TODO Validate loan status

        return loandId;
    }

    function createFrozenLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan(false);

        vm.prank(LENDER_1);
        market.freeze(loanId);

        // TODO Validate loan status

        return loandId;
    }

    function createDefaultedLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        skip(loan.durationInPeriods * loan.periodInSeconds + 1);

        // TODO Validate loan status

        return loandId;
    }

    function createRecoveredLoan() internal returns (uint256 loanId) {
        uint256 loandId = createDefaultedLoan();
        Loan.State memory loan = market.getLoan(loanId);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), outstandingBalance);
        market.repayLoan(loanId, outstandingBalance);
        vm.stopPrank();

        // TODO Validate loan status

        return loandId;
    }

    /************************************************
     *  Test `pause` function
     ***********************************************/

    function test_pause() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        market.pause();
        assertEq(market.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        assertEq(market.paused(), false);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.pause();
    }

    /************************************************
     *  Test `unpause` function
     ***********************************************/

    function test_unpause() public {
        vm.startPrank(OWNER);
        assertEq(market.paused(), false);
        market.pause();
        assertEq(market.paused(), true);
        market.unpause();
        assertEq(market.paused(), false);
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        market.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.unpause();
    }

    /************************************************
     *  Test `setRegistry` function
     ***********************************************/

    function test_setRegistry() public {
        assertEq(market.registry(), REGISTRY);
        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(market));
        emit SetRegistry(address(0), REGISTRY);
        market.setRegistry(address(0));
        assertEq(market.registry(), address(0));

        vm.expectEmit(true, true, true, true, address(market));
        emit SetRegistry(REGISTRY, address(0));
        market.setRegistry(REGISTRY);
        assertEq(market.registry(), REGISTRY);
    }

    function test_setRegistry_Revert_IfAlreadyConfigured() public {
        assertEq(market.registry(), REGISTRY);
        vm.prank(OWNER);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.setRegistry(REGISTRY);
    }

    function test_setRegistry_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.setRegistry(REGISTRY);
    }

    /************************************************
     *  Test `registerCreditLine` function
     ***********************************************/

    function test_registerCreditLine() public {
        assertEq(market.getLender(address(creditLine)), address(0));

        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterCreditLine(LENDER_1, address(creditLine));
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getLender(address(creditLine)), LENDER_1);
    }

    function test_registerCreditLine_Revert_IfLenderAddressZero() public {
        vm.startPrank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(address(0), address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCreditLineAddressZero() public {
        vm.startPrank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(LENDER_1, address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        vm.startPrank(REGISTRY);
        market.registerCreditLine(LENDER_1, address(creditLine));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(REGISTRY);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER_1, address(liquidityPool));
    }

    function test_registerCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    /************************************************
     *  Test `registerLiquidityPool` function
     ***********************************************/

    function test_registerLiquidityPool() public {
        assertEq(market.getLiquidityPool(LENDER_1), address(0));

        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterLiquidityPool(LENDER_1, address(liquidityPool));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPool(LENDER_1), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_lfLenderAddressZero() public {
        vm.prank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(address(0), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfPoolAddressZero() public {
        vm.prank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(LENDER_1, address(0));
    }

    function test_registerLiquidityPool_Revert_IfPoolIsAlreadyRegistered() public {
        vm.startPrank(REGISTRY);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(REGISTRY);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    /************************************************
     *  Test `takeLoan` function
     ***********************************************/

    function test_takeLoan() public {
        configureMarket();
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms(false);
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        assertEq(token.balanceOf(BORROWER_1), 0);
        assertEq(token.balanceOf(terms.addonRecipient), 0);
        assertEq(token.balanceOf(address(liquidityPool)), borrowAmount + terms.addonAmount);
        assertEq(market.balanceOf(LENDER_1), 0);
        assertEq(market.totalSupply(), 0);

        uint256 loanId = 0;
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnBeforeLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(market));
        emit TakeLoan(loanId, BORROWER_1, borrowAmount + terms.addonAmount);

        vm.prank(BORROWER_1);
        assertEq(market.takeLoan(address(creditLine), borrowAmount), loanId);

        Loan.State memory loan = market.getLoan(loanId);
        (, uint256 startDate) = market.getLoanBalance(loanId, 0);

        assertEq(market.ownerOf(loanId), LENDER_1);
        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.balanceOf(BORROWER_1), borrowAmount);
        assertEq(token.balanceOf(terms.addonRecipient), terms.addonAmount);
        assertEq(market.balanceOf(LENDER_1), 1);
        assertEq(market.totalSupply(), 1);

        assertEq(loan.borrower, BORROWER_1);
        assertEq(loan.startDate, startDate);
        assertEq(loan.trackDate, startDate);
        assertEq(loan.freezeDate, 0);
        assertEq(loan.initialBorrowAmount, borrowAmount + terms.addonAmount);
        assertEq(loan.trackedBorrowAmount, borrowAmount + terms.addonAmount);

        assertEq(loan.token, terms.token);
        assertEq(loan.periodInSeconds, terms.periodInSeconds);
        assertEq(loan.durationInPeriods, terms.durationInPeriods);
        assertEq(loan.interestRateFactor, terms.interestRateFactor);
        assertEq(loan.interestRatePrimary, terms.interestRatePrimary);
        assertEq(loan.interestRateSecondary, terms.interestRateSecondary);
        assertEq(uint256(loan.interestFormula), uint256(terms.interestFormula));
    }

    function test_takeLoan_Revert_IfContractIsPaused() public {
        (uint256 borrowAmount, ) = mockLoanTerms(false);

        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    function test_takeLoan_Revert_IfBorrowAmountIsZero() public {
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(address(creditLine), 0);
    }

    function test_takeLoan_Revert_IfCreditLineIsZeroAddress() public {
        (uint256 borrowAmount, ) = mockLoanTerms(false);
        vm.prank(BORROWER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.takeLoan(address(0), borrowAmount);
    }

    function test_takeLoan_Revert_IfCreditLineIsNotRegistered() public {
        (uint256 borrowAmount, ) = mockLoanTerms(false);
        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    function test_takeLoan_Revert_IfLiquidityPoolIsNotRegistered() public {
        (uint256 borrowAmount, ) = mockLoanTerms(false);

        vm.prank(REGISTRY);
        market.registerCreditLine(LENDER_1, address(creditLine));

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    /************************************************
     *  Test `repayLoan` function
     ***********************************************/

    function test_repayLoan_IfBorrower() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        // Partial repayment

        skip(loan.periodInSeconds * 2);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;

        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        (uint256 newOutstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(newOutstandingBalance, outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER_1);

        // Full repayment

        skip(loan.periodInSeconds * 3);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(outstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
    }

    function test_repayLoan_IfLiquidityPool() public {
        configureMarket();
        uint256 loanId = createActiveLoan(true);
        Loan.State memory loan = market.getLoan(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);

        vm.prank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        vm.startPrank(address(liquidityPool));

        // Partial repayment

        skip(loan.periodInSeconds * 2);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;

        token.mint(address(market), outstandingBalance - token.balanceOf(BORROWER_1));
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, address(liquidityPool), BORROWER_1, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        (uint256 newOutstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(newOutstandingBalance, outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER_1);

        // Full repayment

        skip(loan.periodInSeconds * 3);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, address(liquidityPool), BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(outstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
        vm.stopPrank();
    }

    function test_repayLoan_Uint256Max() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        skip(loan.durationInPeriods / 2 * loan.periodInSeconds);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, type(uint256).max);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(outstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
    }

    function test_repayLoan_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();
        Loan.State memory loan = market.getLoan(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        // Partial repayment

        skip(loan.periodInSeconds * 2);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;

        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        (uint256 newOutstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(newOutstandingBalance, outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER_1);

        // Full repayment

        skip(loan.periodInSeconds * 3);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        (outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(outstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
    }

    function test_repayLoan_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, 1);
    }

    function test_repayLoan_Revert_IfAmountIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, 0);
    }

    function test_repayLoan_Revert_IfAmountIsIsGreaterThanBorrowAmount() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        skip(loan.durationInPeriods / 2 * loan.periodInSeconds);

        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1) + 1);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, outstandingBalance + 1);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(NONEXISTENT_LOAN_ID, 1);
    }

    function test_repayLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.repayLoan(loanId, loan.trackedBorrowAmount);
    }

    function test_repayLoan_IfAutoRepaymentNotAllowed() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);
        (uint256 outstandingBalance, ) = market.getLoanBalance(loanId, 0);
        uint256 repayAmount = outstandingBalance / 2;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.prank(address(liquidityPool));
        vm.expectRevert(LendingMarket.AutoRepaymentNotAllowed.selector);
        market.repayLoan(loanId, repayAmount);
    }

    /************************************************
     *  Test `freeze` function
     ***********************************************/

    function test_freeze() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        Loan.State memory loan = market.getLoan(loanId);
        assertEq(loan.freezeDate, 0);

        skip(loan.periodInSeconds * 2);
        (, uint256 currentDate) = market.getLoanBalance(loanId, 0);

        vm.startPrank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit FreezeLoan(loanId, currentDate);
        market.freeze(loanId);

        loan = market.getLoan(loanId);
        assertEq(loan.freezeDate, currentDate);
    }

    function test_freeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.freeze(NONEXISTENT_LOAN_ID);
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.freeze(loanId);
    }

    /************************************************
     *  Test `unfreeze` function
     ***********************************************/

    function test_unfreeze_SameDate() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();
        Loan.State memory loan = market.getLoan(loanId);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        (uint256 oldOutstandingBalance, uint256 currentDate) = market.getLoanBalance(loanId, 0);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UnfreezeLoan(loanId, currentDate);
        market.unfreeze(loanId);

        loan = market.getLoan(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackDate, currentDate);
        assertEq(loan.durationInPeriods, oldDurationInPeriods);
        (uint256 newOutstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(newOutstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_DifferentDate() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();
        Loan.State memory loan = market.getLoan(loanId);

        (uint256 oldOutstandingBalance, uint256 currentDate) = market.getLoanBalance(loanId, 0);
        uint256 oldDurationInPeriods = loan.durationInPeriods;

        skip(loan.periodInSeconds * 2);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UnfreezeLoan(loanId, currentDate + loan.periodInSeconds * 2);
        market.unfreeze(loanId);

        loan = market.getLoan(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackDate, currentDate + loan.periodInSeconds * 2);
        assertEq(loan.durationInPeriods, oldDurationInPeriods + 2);
        (uint256 newOutstandingBalance, ) = market.getLoanBalance(loanId, 0);
        assertEq(newOutstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.unfreeze(NONEXISTENT_LOAN_ID);
    }

    function test_unfreeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.unfreeze(loanId);
    }

    /************************************************
     *  Test `updateLoanDuration` function
     ***********************************************/

    function test_updateLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 newDurationInPeriods = oldDurationInPeriods + 5;

        assertEq(oldDurationInPeriods, INIT_BORROWER_DURATION_IN_PERIODS);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanDuration(loanId, newDurationInPeriods, oldDurationInPeriods);
        market.updateLoanDuration(loanId, newDurationInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.durationInPeriods, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanDuration(NONEXISTENT_LOAN_ID, 123);
    }

    function test_updateLoanDuration_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfInappropriateLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods - 1);
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfNewMoratoriumIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, 0);
    }

    /************************************************
     *  Test `updateLoanMoratorium` function
     ***********************************************/

    function test_updateLoanMoratorium() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldTrackDate = loan.trackDate;
        uint256 newMoratoriumInPeriods = 2;

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanMoratorium(loanId, loan.trackDate, newMoratoriumInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.trackDate, oldTrackDate + newMoratoriumInPeriods * loan.periodInSeconds);

        oldTrackDate = loan.trackDate;
        newMoratoriumInPeriods = 3;

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanMoratorium(loanId, loan.trackDate, newMoratoriumInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.trackDate, oldTrackDate + newMoratoriumInPeriods * loan.periodInSeconds);
    }

    function test_updateLoanMoratorium_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanMoratorium(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanMoratorium_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfLoanMoratoriumDecreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.startPrank(LENDER_1);
        market.updateLoanMoratorium(loanId, 2);
        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    /************************************************
     *  Test `updateLoanInterestRatePrimary` function
     ***********************************************/

    function test_updateLoanInterestRatePrimary() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldInterestRatePrimary = loan.interestRatePrimary;

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanInterestRatePrimary(loanId, oldInterestRatePrimary - 1, oldInterestRatePrimary);
        market.updateLoanInterestRatePrimary(loanId, oldInterestRatePrimary - 1);

        loan = market.getLoan(loanId);
        assertEq(loan.interestRatePrimary, oldInterestRatePrimary - 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRatePrimary(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfInterestRateIncreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(loanId, loan.interestRatePrimary + 1);
    }

    /************************************************
     *  Test `updateLoanInterestRateSecondary` function
     ***********************************************/

    function test_updateLoanInterestRateSecondary() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldInterestRateSecondary = loan.interestRateSecondary;

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanInterestRateSecondary(loanId, oldInterestRateSecondary - 1, oldInterestRateSecondary);
        market.updateLoanInterestRateSecondary(loanId, oldInterestRateSecondary - 1);

        loan = market.getLoan(loanId);
        assertEq(loan.interestRateSecondary, oldInterestRateSecondary - 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRateSecondary(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfInterestRateIncreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan(false);
        Loan.State memory loan = market.getLoan(loanId);

        vm.startPrank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(loanId, loan.interestRateSecondary + 1);
    }

    /************************************************
     *  Test `updateLender` function
     ***********************************************/

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        market.updateLender(address(creditLine), LENDER_1);
    }

    /************************************************
     *  Test view functions
     ***********************************************/

    function test_calculatePeriodDate_1_second_period() public {
        uint256 periodInSeconds = 1 seconds;
        uint256 currentPeriodsSeconds = block.timestamp % periodInSeconds;
        uint256 currentPeriodDate = market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentPeriodDate);

        skip(1);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentPeriodDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 2, 0), currentPeriodDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 3), currentPeriodDate + periodInSeconds + 3);
    }

    function test_calculatePeriodDate_59_seconds_period() public {
        uint256 periodInSeconds = 59 seconds;
        uint256 currentPeriodsSeconds = block.timestamp % periodInSeconds;
        uint256 currentPeriodDate = market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0);

        skip(periodInSeconds - currentPeriodsSeconds - 1);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentPeriodDate);

        skip(1);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentPeriodDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 2, 0), currentPeriodDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 3), currentPeriodDate + periodInSeconds + 3);
    }

    function test_getLender() public {
        assertEq(market.getLender(address(creditLine)), address(0));
        vm.prank(REGISTRY);
        market.registerCreditLine(LENDER_1, address(creditLine));
        assertEq(market.getLender(address(creditLine)), LENDER_1);
    }

    function test_getLiquidityPool() public {
        assertEq(market.getLiquidityPool(LENDER_1), address(0));
        vm.prank(REGISTRY);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        assertEq(market.getLiquidityPool(LENDER_1), address(liquidityPool));
    }

    function test_supportsInterface() public {
        assertEq(market.supportsInterface(0x0), false);
        assertEq(market.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(market.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(market.supportsInterface(0x5b5e139f), true); // ERC721Metadata
        assertEq(market.supportsInterface(0x780e9d63), true); // ERC721Enumerable
    }
}

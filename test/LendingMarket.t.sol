// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LendingMarket} from "src/LendingMarket.sol";
import {CreditLineMock} from "./mocks/CreditLineMock.sol";
import {LiquidityPoolMock} from "./mocks/LiquidityPoolMock.sol";
import {ERC20Test} from "./mocks/ERC20Test.sol";

/// @title LendingMarketTest contract
/// @notice Tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketTest is Test {

    /************************************************
     *  Events
     ***********************************************/

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event LoanFrozen(uint256 indexed loanId, uint256 freezeDate);
    event LoanUnfrozen(uint256 indexed loanId, uint256 unfreezeDate);

    event CreditLineRegistered(address indexed lender, address indexed creditLine);
    event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);
    event LoanTaken(uint256 indexed loanId, address indexed borrower, uint256 borrowAmount);
    event LoanRepaid(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );
    event LoanDurationUpdated(uint256 indexed loanId, uint256 indexed newDuration, uint256 indexed oldDuration);
    event LoanMoratoriumUpdated(uint256 indexed loanId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
    event LoanInterestRatePrimaryUpdated(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event LoanInterestRateSecondaryUpdated(
        uint256 indexed loanId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event RegistryUpdated(address indexed newRegistry, address indexed oldRegistry);
    event LoanStatusChanged(uint256 indexed loanId, Loan.Status indexed newStatus, Loan.Status indexed oldStatus);

    /************************************************
     *  Storage variables and constants
     ***********************************************/

    uint256 public constant DEPOSIT_AMOUNT = 100;
    uint256 public constant LOAN_DURATION_IN_PERIODS = 36;
    uint256 public constant LOAN_PERIOD_IN_SECONDS = 86400;
    uint256 public constant LOAN_INTEREST_RATE_PRIMARY = 100;
    uint256 public constant LOAN_INTEREST_RATE_SECONDARY = 200;
    uint256 public constant LOAN_INTEREST_RATE_FACTOR = 1;
    Interest.Formula public constant LOAN_INTEREST_FORMULA = Interest.Formula.Compound;
    uint256 public constant ADDON_AMOUNT = 100;
    uint256 public constant NONEXISTENT_LOAN_ID = 9999999;

    ERC20Test public token;
    LendingMarket public market;
    CreditLineMock public creditLine;
    LiquidityPoolMock public liquidityPool;

    address public OWNER = address(this);
    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant BORROWER = address(bytes20(keccak256("borrower")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint256 public constant INIT_BLOCK_TIMESTAMP = LOAN_PERIOD_IN_SECONDS + 1;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        token = new ERC20Test(0);
        creditLine = new CreditLineMock();
        liquidityPool = new LiquidityPoolMock();

        market = LendingMarket(address(new ERC1967Proxy(address(new LendingMarket()), "")));
        market.initialize("NAME", "SYMBOL");
        market.setRegistry(REGISTRY);
        market.transferOwnership(OWNER);

        vm.prank(address(liquidityPool));
        token.approve(address(market), type(uint256).max);

        skip(INIT_BLOCK_TIMESTAMP);
    }

    function configureMarket() internal {
        vm.startPrank(REGISTRY);
        market.registerCreditLine(LENDER, address(creditLine));
        market.registerLiquidityPool(LENDER, address(liquidityPool));
        vm.stopPrank();
    }

    function mockLoanTerms() internal returns (Loan.Terms memory) {
        Loan.Terms memory terms = Loan.Terms({
            token: address(token),
            periodInSeconds: LOAN_PERIOD_IN_SECONDS,
            durationInPeriods: LOAN_DURATION_IN_PERIODS,
            interestRateFactor: LOAN_INTEREST_RATE_FACTOR,
            interestRatePrimary: LOAN_INTEREST_RATE_PRIMARY,
            interestRateSecondary: LOAN_INTEREST_RATE_SECONDARY,
            interestFormula: LOAN_INTEREST_FORMULA,
            addonRecipient: ADDON_RECIPIENT,
            addonAmount: ADDON_AMOUNT
        });
        creditLine.mockLoanTerms(BORROWER, DEPOSIT_AMOUNT, terms);
        return terms;
    }

    function createActiveLoan() internal returns (uint256 loanId) {
        Loan.Terms memory terms = mockLoanTerms();
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT + ADDON_AMOUNT);

        vm.prank(BORROWER);
        loanId = market.takeLoan(address(creditLine), DEPOSIT_AMOUNT);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Active));

        return loanId;
    }

    function createRepaidLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan();

        skip(LOAN_DURATION_IN_PERIODS * LOAN_PERIOD_IN_SECONDS / 2);

        Loan.State memory loan = market.getLoan(loanId);

        uint256 originalBalance = loan.trackedBorrowAmount;
        uint256 numberOfPeriods = LOAN_DURATION_IN_PERIODS / 2;
        uint256 interestRate = LOAN_INTEREST_RATE_PRIMARY;
        uint256 interestRateFactor = LOAN_INTEREST_RATE_FACTOR;
        Interest.Formula interestFormula = LOAN_INTEREST_FORMULA;

        uint256 outstandingBalance = market.calculateOutstandingBalance(
            originalBalance,
            numberOfPeriods,
            interestRate,
            interestRateFactor,
            interestFormula
        );

        vm.prank(LENDER);
        market.approve(address(market), loandId);

        token.mint(BORROWER, outstandingBalance);

        vm.prank(BORROWER);
        token.approve(address(market), outstandingBalance);

        vm.prank(BORROWER);
        market.repayLoan(loanId, outstandingBalance);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Repaid));

        return loandId;
    }

    function createFrozenLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan();

        // TODO add loan duration

        assertEq(market.ownerOf(loanId), LENDER);


        // TODO why can't freeze after 10 seconds???

        //skip(LOAN_DURATION_IN_PERIODS * LOAN_PERIOD_IN_SECONDS + 1);

        vm.prank(LENDER);
        market.freeze(loanId);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Frozen));

        return loandId;
    }

    function createDefaultedLoan() internal returns (uint256 loanId) {
        uint256 loandId = createActiveLoan();
        skip(LOAN_DURATION_IN_PERIODS * LOAN_PERIOD_IN_SECONDS + 1);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Defaulted));

        return loandId;
    }

    function createRecoveredLoan() internal returns (uint256 loanId) {
        uint256 loandId = createDefaultedLoan();
        Loan.State memory loan = market.getLoan(loanId);
        uint256 outstandingBalance = market.getOutstandingBalance(loanId);

        vm.prank(LENDER);
        market.approve(address(market), loandId);

        token.mint(BORROWER, outstandingBalance);

        vm.prank(BORROWER);
        token.approve(address(market), outstandingBalance);

        vm.prank(BORROWER);
        market.repayLoan(loanId, outstandingBalance);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Recovered));

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
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
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

    function test_unpause_Revert_IfContractIsNotPaused() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        market.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        market.unpause();
    }

    /************************************************
     *  Test `setRegistry` function
     ***********************************************/

    function test_setRegistry() public {
        assertEq(market.registry(), REGISTRY);
        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(market));
        emit RegistryUpdated(address(0), REGISTRY);
        market.setRegistry(address(0));
        assertEq(market.registry(), address(0));

        vm.expectEmit(true, true, true, true, address(market));
        emit RegistryUpdated(REGISTRY, address(0));
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
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        market.setRegistry(REGISTRY);
    }

    /************************************************
     *  Test `registerCreditLine` function
     ***********************************************/

    function test_registerCreditLine() public {
        assertEq(market.getLender(address(creditLine)), address(0));

        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineRegistered(LENDER, address(creditLine));
        market.registerCreditLine(LENDER, address(creditLine));

        assertEq(market.getLender(address(creditLine)), LENDER);
    }

    function test_registerCreditLine_Revert_IfLenderAddressZero() public {
        vm.startPrank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(address(0), address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCreditLineAddressZero() public {
        vm.startPrank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(LENDER, address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        vm.startPrank(REGISTRY);
        market.registerCreditLine(LENDER, address(creditLine));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        market.registerCreditLine(LENDER, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(REGISTRY);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER, address(liquidityPool));
    }

    function test_registerCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerCreditLine(LENDER, address(creditLine));
    }

    /************************************************
     *  Test `registerLiquidityPool` function
     ***********************************************/

    function test_registerLiquidityPool() public {
        assertEq(market.getLiquidityPool(LENDER), address(0));

        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolRegistered(LENDER, address(liquidityPool));
        market.registerLiquidityPool(LENDER, address(liquidityPool));

        assertEq(market.getLiquidityPool(LENDER), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_lfLenderAddressZero() public {
        vm.prank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(address(0), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfPoolAddressZero() public {
        vm.prank(REGISTRY);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(LENDER, address(0));
    }

    function test_registerLiquidityPool_Revert_IfPoolIsAlreadyRegistered() public {
        vm.startPrank(REGISTRY);
        market.registerLiquidityPool(LENDER, address(liquidityPool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        market.registerLiquidityPool(LENDER, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(REGISTRY);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerLiquidityPool(LENDER, address(liquidityPool));
    }

    /************************************************
     *  Test `takeLoan` function
     ***********************************************/

    function test_takeLoan() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms();
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT + ADDON_AMOUNT);

        assertEq(token.balanceOf(BORROWER), 0);
        assertEq(token.balanceOf(ADDON_RECIPIENT), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT + ADDON_AMOUNT);
        assertEq(market.balanceOf(LENDER), 0);
        assertEq(market.totalSupply(), 0);

        uint256 loanId = 0;
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnBeforeLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanTaken(loanId, BORROWER, DEPOSIT_AMOUNT + ADDON_AMOUNT);

        vm.prank(BORROWER);
        assertEq(market.takeLoan(address(creditLine), DEPOSIT_AMOUNT), loanId);

        Loan.State memory loan = market.getLoan(loanId);
        uint256 startDate = market.getCurrentPeriodDate(loanId);

        assertEq(market.ownerOf(loanId), LENDER);
        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.balanceOf(BORROWER), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(ADDON_RECIPIENT), ADDON_AMOUNT);
        assertEq(market.balanceOf(LENDER), 1);
        assertEq(market.totalSupply(), 1);

        assertEq(loan.borrower, BORROWER);
        assertEq(loan.startDate, startDate);
        assertEq(loan.trackDate, startDate);
        assertEq(loan.freezeDate, 0);
        assertEq(loan.initialBorrowAmount, DEPOSIT_AMOUNT + ADDON_AMOUNT);
        assertEq(loan.trackedBorrowAmount, DEPOSIT_AMOUNT + ADDON_AMOUNT);

        assertEq(loan.token, terms.token);
        assertEq(loan.periodInSeconds, terms.periodInSeconds);
        assertEq(loan.durationInPeriods, terms.durationInPeriods);
        assertEq(loan.interestRateFactor, terms.interestRateFactor);
        assertEq(loan.interestRatePrimary, terms.interestRatePrimary);
        assertEq(loan.interestRateSecondary, terms.interestRateSecondary);
        assertEq(uint256(loan.interestFormula), uint256(terms.interestFormula));
    }

    function test_takeLoan_Revert_IfContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoan(address(creditLine), DEPOSIT_AMOUNT);
    }

    function test_takeLoan_Revert_IfBorrowAmountIsZero() public {
        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(address(creditLine), 0);
    }

    function test_takeLoan_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(BORROWER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.takeLoan(address(0), DEPOSIT_AMOUNT);
    }

    function test_takeLoan_Revert_IfCreditLineIsNotRegistered() public {
        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        market.takeLoan(address(creditLine), DEPOSIT_AMOUNT);
    }

    function test_takeLoan_Revert_IfLiquidityPoolIsNotRegistered() public {
        vm.prank(REGISTRY);
        market.registerCreditLine(LENDER, address(creditLine));

        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.takeLoan(address(creditLine), DEPOSIT_AMOUNT);
    }

    // /************************************************
    //  *  Test `repayLoan` function
    //  ***********************************************/

    function test_repayLoan() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Active));
        assertEq(market.ownerOf(loanId), LENDER);

        vm.startPrank(BORROWER);
        token.approve(address(market), type(uint256).max);

        // Partial repayment

        skip(LOAN_PERIOD_IN_SECONDS * 2);

        uint256 outstandingBalance = market.getOutstandingBalance(loanId);
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;

        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepaid(loanId, BORROWER, BORROWER, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        // (status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Active));
        assertEq(market.getOutstandingBalance(loanId), outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER);

        // Full repayment

        skip(LOAN_PERIOD_IN_SECONDS * 3);

        outstandingBalance = market.getOutstandingBalance(loanId);
        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepaid(loanId, BORROWER, BORROWER, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        // (status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Repaid));
        assertEq(market.getOutstandingBalance(loanId), 0);
        assertEq(market.ownerOf(loanId), BORROWER);
    }

    function test_repayLoan_Uint256Max() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        // (Loan.Status status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Active));
        assertEq(market.ownerOf(loanId), LENDER);

        vm.startPrank(BORROWER);
        token.approve(address(market), type(uint256).max);

        skip(LOAN_DURATION_IN_PERIODS / 2 * LOAN_PERIOD_IN_SECONDS);

        uint256 outstandingBalance = market.getOutstandingBalance(loanId);
        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepaid(loanId, BORROWER, BORROWER, outstandingBalance, 0);
        market.repayLoan(loanId, type(uint256).max);

        // (status, ) = market.getLoan(loanId);
        // assertEq(uint256(status), uint256(Loan.Status.Repaid));
        assertEq(market.getOutstandingBalance(loanId), 0);
        assertEq(market.ownerOf(loanId), BORROWER);
    }

    function test_repayLoan_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();
        Loan.State memory loan = market.getLoan(loanId);

        assertEq(market.ownerOf(loanId), LENDER);

        vm.startPrank(BORROWER);
        token.approve(address(market), type(uint256).max);

        // Partial repayment

        skip(LOAN_PERIOD_IN_SECONDS * 2);

        uint256 outstandingBalance = market.getOutstandingBalance(loanId);
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;

        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepaid(loanId, BORROWER, BORROWER, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        assertEq(market.getOutstandingBalance(loanId), outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER);

        // Full repayment

        skip(LOAN_PERIOD_IN_SECONDS * 3);

        outstandingBalance = market.getOutstandingBalance(loanId);
        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepaid(loanId, BORROWER, BORROWER, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        assertEq(market.getOutstandingBalance(loanId), 0);
        assertEq(market.ownerOf(loanId), BORROWER);
    }

    function test_repayLoan_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, 1);
    }

    function test_repayLoan_Revert_IfAmountIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, 0);
    }

    function test_repayLoan_Revert_IfAmountIsGreaterThanBorrowAmount() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        skip(LOAN_DURATION_IN_PERIODS / 2 * LOAN_PERIOD_IN_SECONDS);

        uint256 outstandingBalance = market.getOutstandingBalance(loanId);
        token.mint(BORROWER, outstandingBalance - token.balanceOf(BORROWER) + 1);

        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, outstandingBalance + 1);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(NONEXISTENT_LOAN_ID, DEPOSIT_AMOUNT);
    }

    function test_repayLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.repayLoan(loanId, DEPOSIT_AMOUNT);
    }

    /************************************************
     *  Test `freeze` function
     ***********************************************/

    function test_freeze() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        Loan.State memory loan = market.getLoan(loanId);
        assertEq(loan.freezeDate, 0);

        skip(LOAN_PERIOD_IN_SECONDS * 2);
        uint256 currentDate = market.getCurrentPeriodDate(loanId);

        vm.startPrank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanFrozen(loanId, currentDate);
        market.freeze(loanId);

        loan = market.getLoan(loanId);
        assertEq(loan.freezeDate, currentDate);
    }

    // function test_freeze_Revert_IfLoanIsDefaulted() public {
    //     configureMarket();
    //     uint256 loanId = createDefaultedLoan();

    //     vm.prank(LENDER);
    //     vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
    //     market.freeze(loanId);
    // }

    function test_freeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.freeze(NONEXISTENT_LOAN_ID);
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

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
        uint256 oldDutstandingBalance = market.getOutstandingBalance(loanId);
        uint256 currentDate = market.getCurrentPeriodDate(loanId);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanUnfrozen(loanId, currentDate);
        market.unfreeze(loanId);

        loan = market.getLoan(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackDate, currentDate);
        assertEq(loan.durationInPeriods, oldDurationInPeriods);
        assertEq(market.getOutstandingBalance(loanId), oldDutstandingBalance);
    }

    function test_unfreeze_DifferentDate() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();
        Loan.State memory loan = market.getLoan(loanId);

        uint256 oldDutstandingBalance = market.getOutstandingBalance(loanId);
        uint256 oldDurationInPeriods = loan.durationInPeriods;

        skip(LOAN_PERIOD_IN_SECONDS * 2);
        uint256 currentDate = market.getCurrentPeriodDate(loanId);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanUnfrozen(loanId, currentDate);
        market.unfreeze(loanId);

        loan = market.getLoan(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackDate, currentDate);
        assertEq(loan.durationInPeriods, oldDurationInPeriods + 2);
        assertEq(market.getOutstandingBalance(loanId), oldDutstandingBalance);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.unfreeze(NONEXISTENT_LOAN_ID);
    }

    function test_unfreeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createFrozenLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER);
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
        uint256 loanId = createActiveLoan();

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 newDurationInPeriods = oldDurationInPeriods + 5;

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanDurationUpdated(loanId, newDurationInPeriods, oldDurationInPeriods);
        market.updateLoanDuration(loanId, newDurationInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.durationInPeriods, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanDuration(NONEXISTENT_LOAN_ID, LOAN_DURATION_IN_PERIODS);
    }

    function test_updateLoanDuration_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfInappropriateLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods - 1);
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(loanId, loan.durationInPeriods + 1);
    }

    function test_updateLoanDuration_Revert_IfNewMoratoriumIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, 0);
    }

    /************************************************
     *  Test `updateLoanMoratorium` function
     ***********************************************/

    function test_updateLoanMoratorium() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldTrackDate = loan.trackDate;
        uint256 newMoratoriumInPeriods = 2;

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanMoratoriumUpdated(loanId, loan.trackDate, newMoratoriumInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.trackDate, oldTrackDate + newMoratoriumInPeriods * loan.periodInSeconds);

        oldTrackDate = loan.trackDate;
        newMoratoriumInPeriods = 3;

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanMoratoriumUpdated(loanId, loan.trackDate, newMoratoriumInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoan(loanId);
        assertEq(loan.trackDate, oldTrackDate + newMoratoriumInPeriods * loan.periodInSeconds);
    }

    function test_updateLoanMoratorium_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfLoanNotExist() public {
        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanMoratorium(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanMoratorium_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    function test_updateLoanMoratorium_Revert_IfLoanMoratoriumDecreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.startPrank(LENDER);
        market.updateLoanMoratorium(loanId, 2);
        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        market.updateLoanMoratorium(loanId, 1);
    }

    // /************************************************
    //  *  Test `updateLoanInterestRatePrimary` function
    //  ***********************************************/

    function test_updateLoanInterestRatePrimary() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldInterestRatePrimary = loan.interestRatePrimary;

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRatePrimaryUpdated(loanId, oldInterestRatePrimary - 1, oldInterestRatePrimary);
        market.updateLoanInterestRatePrimary(loanId, oldInterestRatePrimary - 1);

        loan = market.getLoan(loanId);
        assertEq(loan.interestRatePrimary, oldInterestRatePrimary - 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRatePrimary(NONEXISTENT_LOAN_ID , 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(loanId, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfInterestRateIncreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(loanId, loan.interestRatePrimary + 1);
    }

    // /************************************************
    //  *  Test `updateLoanInterestRateSecondary` function
    //  ***********************************************/

    function test_updateLoanInterestRateSecondary() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        Loan.State memory loan = market.getLoan(loanId);
        uint256 oldInterestRateSecondary = loan.interestRateSecondary;

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRateSecondaryUpdated(loanId, oldInterestRateSecondary - 1, oldInterestRateSecondary);
        market.updateLoanInterestRateSecondary(loanId, oldInterestRateSecondary - 1);

        loan = market.getLoan(loanId);
        assertEq(loan.interestRateSecondary, oldInterestRateSecondary - 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRateSecondary(NONEXISTENT_LOAN_ID , 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan();

        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfCallerNotLoanHolder() public {
        configureMarket();
        uint256 loanId = createActiveLoan();

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(loanId, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfInterestRateIncreased() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.startPrank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(loanId, loan.interestRateSecondary + 1);
    }

    /************************************************
     *  Test `updateLender` function
     ***********************************************/

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        market.updateLender(address(creditLine), LENDER);
    }

    /************************************************
     *  Test view functions
     ***********************************************/

    function test_calculatePeriodDate_1_second_period() public {
        uint256 periodInSeconds = 1 seconds;
        uint256 currentPeriodsSeconds = block.timestamp % periodInSeconds;
        uint256 currentPeriodDate = market.calculatePeriodDate(periodInSeconds, 0, 0);

        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 0), currentPeriodDate);

        skip(1);
        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 0), currentPeriodDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(periodInSeconds, 2, 0), currentPeriodDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 3), currentPeriodDate + periodInSeconds + 3);
    }

    function test_calculatePeriodDate_59_seconds_period() public {
        uint256 periodInSeconds = 59 seconds;
        uint256 currentPeriodsSeconds = block.timestamp % periodInSeconds;
        uint256 currentPeriodDate = market.calculatePeriodDate(periodInSeconds, 0, 0);

        skip(periodInSeconds - currentPeriodsSeconds - 1);
        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 0), currentPeriodDate);

        skip(1);
        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 0), currentPeriodDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(periodInSeconds, 2, 0), currentPeriodDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(periodInSeconds, 0, 3), currentPeriodDate + periodInSeconds + 3);
    }

    function test_getLender() public {
        assertEq(market.getLender(address(creditLine)), address(0));
        vm.prank(REGISTRY);
        market.registerCreditLine(LENDER, address(creditLine));
        assertEq(market.getLender(address(creditLine)), LENDER);
    }

    function test_getLoanPreview() public {
        configureMarket();
        uint256 loanId = createActiveLoan();
        Loan.State memory loan = market.getLoan(loanId);

        vm.expectRevert(Error.NotImplemented.selector);
        market.getLoanPreview(loanId, 0, block.timestamp + loan.periodInSeconds * 2);
    }

    function test_getLiquidityPool() public {
        assertEq(market.getLiquidityPool(LENDER), address(0));
        vm.prank(REGISTRY);
        market.registerLiquidityPool(LENDER, address(liquidityPool));
        assertEq(market.getLiquidityPool(LENDER), address(liquidityPool));
    }

    function test_supportsInterface() public {
        assertEq(market.supportsInterface(0x0), false);
        assertEq(market.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(market.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(market.supportsInterface(0x5b5e139f), true); // ERC721Metadata
        assertEq(market.supportsInterface(0x780e9d63), true); // ERC721Enumerable
    }

    function test_upgrade() public {
        address newMarket = address(new LendingMarket());

        vm.prank(OWNER);
        market.upgradeToAndCall(newMarket, "");

        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        market.upgradeToAndCall(newMarket, "");
    }


    // function test_getLoan() public {
    //     market.getLoan(0);
    // }

    // function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
    //     external
    //     pure
    //     returns (bytes4)
    // {
    //     return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    // }
}

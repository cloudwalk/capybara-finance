// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/libraries/Loan.sol";
import { Error } from "src/libraries/Error.sol";
import { Interest } from "src/libraries/Interest.sol";

import { ERC20Mock } from "src/mocks/ERC20Mock.sol";
import { LendingMarket } from "src/LendingMarket.sol";
import { CreditLineMock } from "src/mocks/CreditLineMock.sol";
import { LiquidityPoolMock } from "src/mocks/LiquidityPoolMock.sol";

import { Config } from "test/base/Config.sol";

/// @title LendingMarketTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LendingMarket` contract.
contract LendingMarketTest is Test, Config {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

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
    event AssignLiquidityPoolToCreditLine(
        address indexed creditLine, address indexed newLiquidityPool, address indexed oldLiquidityPool
    );
    event ConfigureLenderAlias(address indexed lender, address indexed account, bool isAlias);
    event SetRegistry(address indexed newRegistry, address indexed oldRegistry);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    ERC20Mock public token;
    LendingMarket public market;
    CreditLineMock public creditLine;
    LiquidityPoolMock public liquidityPool;

    uint256 public constant NONEXISTENT_LOAN_ID = 9_999_999;
    uint256 public constant INIT_BLOCK_TIMESTAMP = INIT_CREDIT_LINE_PERIOD_IN_SECONDS + 1;

    bool public canOverrideAutoRepayment = false;
    bool public overrideAutoRepayment = false;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        token = new ERC20Mock(0);
        creditLine = new CreditLineMock();
        liquidityPool = new LiquidityPoolMock();

        market = new LendingMarket();
        market.initialize("NAME", "SYMBOL");
        market.setRegistry(REGISTRY_1);
        market.transferOwnership(OWNER);

        skip(INIT_BLOCK_TIMESTAMP);
    }

    function configureMarket() private {
        vm.startPrank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.stopPrank();

        vm.startPrank(LENDER_1);
        market.configureAlias(LENDER_1_ALIAS, true);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
        vm.stopPrank();

        vm.prank(address(liquidityPool));
        token.approve(address(market), type(uint256).max);
    }

    function mockLoanTerms() private returns (uint256, Loan.Terms memory) {
        Loan.Terms memory terms = initLoanTerms(address(token));

        if (canOverrideAutoRepayment) {
            terms.autoRepayment = overrideAutoRepayment;
        }

        terms.holder = address(liquidityPool);

        creditLine.mockLoanTerms(BORROWER_1, BORROW_AMOUNT, terms);

        return (BORROW_AMOUNT, terms);
    }

    function createActiveLoan(uint256 skipPeriodsAfterCreated) private returns (uint256) {
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        vm.prank(BORROWER_1);
        uint256 loanId = market.takeLoan(address(creditLine), borrowAmount);

        Loan.State memory loan = market.getLoanState(loanId);
        skip(loan.periodInSeconds * skipPeriodsAfterCreated);

        return loanId;
    }

    function createFrozenLoan(uint256 skipPeriodsBeforeFreezing) private returns (uint256) {
        uint256 loanId = createActiveLoan(skipPeriodsBeforeFreezing);

        vm.prank(LENDER_1);
        market.freeze(loanId);

        return loanId;
    }

    function createRepaidLoan(uint256 skipPeriodsBeforeRepayment) private returns (uint256) {
        uint256 loanId = createActiveLoan(skipPeriodsBeforeRepayment);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance != 0, true);
        token.mint(BORROWER_1, outstandingBalance);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), outstandingBalance);
        market.repayLoan(loanId, outstandingBalance);
        vm.stopPrank();

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance == 0, true);

        return loanId;
    }

    function createDefaultedLoan(uint256 skipPeriodsAfterDefault) private returns (uint256) {
        uint256 loanId = createActiveLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);

        skip(loan.periodInSeconds * loan.durationInPeriods);
        skip(loan.periodInSeconds * skipPeriodsAfterDefault);

        return loanId;
    }

    // -------------------------------------------- //
    //  Test `initialize` function                  //
    // -------------------------------------------- //

    function test_initialize() public {
        market = new LendingMarket();
        market.initialize("NAME", "SYMBOL");

        assertEq(market.name(), "NAME");
        assertEq(market.symbol(), "SYMBOL");
        assertEq(market.owner(), address(this));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize("NEW_NAME", "NEW_SYMBOL");
    }

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

    function test_pause() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        market.pause();
        assertEq(market.paused(), true);
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        assertEq(market.paused(), false);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.pause();
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.pause();
    }

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

    function test_unpause() public {
        vm.startPrank(OWNER);
        assertEq(market.paused(), false);
        market.pause();
        assertEq(market.paused(), true);
        market.unpause();
        assertEq(market.paused(), false);
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        market.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.unpause();
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    // -------------------------------------------- //
    //  Test `setRegistry` function                 //
    // -------------------------------------------- //

    function test_setRegistry() public {
        assertEq(market.registry(), REGISTRY_1);

        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(market));
        emit SetRegistry(address(0), REGISTRY_1);
        market.setRegistry(address(0));
        assertEq(market.registry(), address(0));

        vm.expectEmit(true, true, true, true, address(market));
        emit SetRegistry(REGISTRY_2, address(0));
        market.setRegistry(REGISTRY_2);
        assertEq(market.registry(), REGISTRY_2);
    }

    function test_setRegistry_Revert_IfCallerNotOwner() public {
        assertEq(market.registry(), REGISTRY_1);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.setRegistry(REGISTRY_2);
    }

    function test_setRegistry_Revert_IfAlreadyConfigured() public {
        assertEq(market.registry(), REGISTRY_1);
        vm.prank(OWNER);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.setRegistry(REGISTRY_1);
    }

    // -------------------------------------------- //
    //  Test `registerCreditLine` function          //
    // -------------------------------------------- //

    function test_registerCreditLine_IfOwner() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterCreditLine(LENDER_1, address(creditLine));
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_registerCreditLine_IfRegistry() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterCreditLine(LENDER_1, address(creditLine));
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_registerCreditLine_Revert_IfOwner_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfRegistry_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(REGISTRY_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCallerNotRegistryOrOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(address(0), address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(LENDER_1, address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    // -------------------------------------------- //
    //  Test `registerLiquidityPool` function       //
    // -------------------------------------------- //

    function test_registerLiquidityPool_IfOwner() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterLiquidityPool(LENDER_1, address(liquidityPool));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_registerLiquidityPool_IfRegistry() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit RegisterLiquidityPool(LENDER_1, address(liquidityPool));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_registerLiquidityPool_Revert_IfOwner_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfRegistry_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(REGISTRY_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotRegistryOrOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(address(0), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(LENDER_1, address(0));
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolIsAlreadyRegistered() public {
        vm.startPrank(OWNER);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    // -------------------------------------------- //
    //  Test `assignLiquidityPoolToCreditLine`      //
    // -------------------------------------------- //

    function test_assignLiquidityPoolToCreditLine() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.stopPrank();

        assertEq(market.getLiquidityPoolByCreditLine(address(creditLine)), address(0));

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit AssignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool), address(0));
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));

        assertEq(market.getLiquidityPoolByCreditLine(address(creditLine)), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfCreditLineIsZeroAddress() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.assignLiquidityPoolToCreditLine(address(0), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfLiquidityPoolIsZeroAddress() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(0));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfAlreadyAssigned() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.NotImplemented.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), LIQUIDITY_POOL_1);
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfWrongCreditLineLender() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_2, address(liquidityPool));
        vm.stopPrank();

        vm.prank(LENDER_2);
        vm.expectRevert(Error.Unauthorized.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfWrongLiquidityPoolLender() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_2, address(liquidityPool));
        vm.stopPrank();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    // -------------------------------------------- //
    //  Test `takeLoan` function                    //
    // -------------------------------------------- //

    function test_takeLoan() public {
        configureMarket();
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();
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

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        assertEq(market.ownerOf(loanId), LENDER_1);
        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.balanceOf(BORROWER_1), borrowAmount);
        assertEq(token.balanceOf(terms.addonRecipient), terms.addonAmount);
        assertEq(market.balanceOf(LENDER_1), 1);
        assertEq(market.totalSupply(), 1);

        assertEq(loan.borrower, BORROWER_1);
        assertEq(loan.startDate, preview.periodDate);
        assertEq(loan.trackedDate, preview.periodDate);
        assertEq(loan.freezeDate, 0);
        assertEq(loan.initialBorrowAmount, borrowAmount + terms.addonAmount);
        assertEq(loan.trackedBorrowAmount, borrowAmount + terms.addonAmount);

        assertEq(loan.token, terms.token);
        assertEq(loan.autoRepayment, terms.autoRepayment);
        assertEq(loan.periodInSeconds, terms.periodInSeconds);
        assertEq(loan.durationInPeriods, terms.durationInPeriods);
        assertEq(loan.interestRateFactor, terms.interestRateFactor);
        assertEq(loan.interestRatePrimary, terms.interestRatePrimary);
        assertEq(loan.interestRateSecondary, terms.interestRateSecondary);
        assertEq(uint256(loan.interestFormula), uint256(terms.interestFormula));
    }

    function test_takeLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        (uint256 borrowAmount,) = mockLoanTerms();

        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    function test_takeLoan_Revert_IfBorrowAmountIsZero() public {
        configureMarket();
        mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(address(creditLine), 0);
    }

    function test_takeLoan_Revert_IfCreditLineIsZeroAddress() public {
        configureMarket();
        (uint256 borrowAmount,) = mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.takeLoan(address(0), borrowAmount);
    }

    function test_takeLoan_Revert_IfCreditLineIsNotRegistered() public {
        (uint256 borrowAmount,) = mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    function test_takeLoan_Revert_IfLiquidityPoolIsNotRegistered() public {
        (uint256 borrowAmount,) = mockLoanTerms();

        vm.prank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount);
    }

    // -------------------------------------------- //
    //  Test `repayLoan` function                  //
    // -------------------------------------------- //

    function repayLoan(uint256 loanId, bool autoRepaymnet) private {
        Loan.State memory loan = market.getLoanState(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);
        assertEq(loan.trackedBorrowAmount >= 2, true);

        vm.prank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        // Repayment mode
        if (autoRepaymnet) {
            vm.startPrank(address(liquidityPool));
        } else {
            vm.startPrank(BORROWER_1);
        }

        // Partial repayment

        skip(loan.periodInSeconds * 2);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        uint256 newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER_1);

        // Full repayment

        skip(loan.periodInSeconds * 3);

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
    }

    function test_repayLoan_IfLoanIsActive() public {
        configureMarket();
        repayLoan(createActiveLoan(1), false);
    }

    function test_repayLoan_IfLoanIsFrozen() public {
        configureMarket();
        repayLoan(createFrozenLoan(1), false);
    }

    function test_repayLoan_IfLoanIsDefaulted() public {
        configureMarket();
        repayLoan(createDefaultedLoan(1), false);
    }

    function test_repayLoan_IfLoanIsActive_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createActiveLoan(1), true);
    }

    function test_repayLoan_IfLoanIsFrozen_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createFrozenLoan(1), true);
    }

    function test_repayLoan_IfLoanIsDefaulted_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createDefaultedLoan(1), true);
    }

    function test_repayLoan_IRepaymentAmountIsUint256Max() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.startPrank(BORROWER_1);

        token.approve(address(market), type(uint256).max);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance != 0, true);

        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit RepayLoan(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, type(uint256).max);

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance, 0);
    }

    function test_repayLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.repayLoan(loanId, loan.trackedBorrowAmount);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        configureMarket();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(NONEXISTENT_LOAN_ID, 1);
    }

    function test_repayLoan_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, 1);
    }

    function test_repayLoan_Revert_IfRepayAmountIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, 0);
    }

    function test_repayLoan_Revert_IfLiquidityPoolIsNotRegistered() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(LENDER_1);
        market.transferFrom(LENDER_1, LENDER_2, loanId);

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.repayLoan(loanId, 1);
    }

    function test_repayLoan_Revert_IfAutoRepaymentIsNotAllowed() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.prank(address(liquidityPool));
        vm.expectRevert(LendingMarket.AutoRepaymentNotAllowed.selector);
        market.repayLoan(loanId, outstandingBalance);
    }

    function test_repayLoan_Revert_IfRepayAmountIsGreaterThanBorrowAmount() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1) + 1);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, outstandingBalance + 1);
    }

    // -------------------------------------------- //
    //  Test `freeze` function                      //
    // -------------------------------------------- //

    function test_freeze(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.freezeDate, 0);

        uint256 currentDate = market.getLoanPreview(loanId, 0).periodDate;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit FreezeLoan(loanId, currentDate);
        market.freeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeDate, currentDate);
    }

    function test_freeze_IfLender() public {
        test_freeze(LENDER_1);
    }

    function test_freeze_IfLenderAlias() public {
        test_freeze(LENDER_1_ALIAS);
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.freeze(NONEXISTENT_LOAN_ID);
    }

    function test_freeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        market.freeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `unfreeze` function                    //
    // -------------------------------------------- //

    function test_unfreeze(address caller) private {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);

        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.freezeDate != 0, true);

        vm.prank(caller);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeDate, 0);
    }

    function test_unfreeze_IfLender() public {
        test_unfreeze(LENDER_1);
    }

    function test_unfreeze_IfLenderAlias() public {
        test_unfreeze(LENDER_1_ALIAS);
    }

    function test_unfreeze_IfSamePeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;
        uint256 currentDate = preview.periodDate;

        assertEq(loan.freezeDate, currentDate);
        assertEq(loan.trackedDate, currentDate);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UnfreezeLoan(loanId, currentDate);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackedDate, currentDate);
        assertEq(loan.durationInPeriods, oldDurationInPeriods);
        uint256 newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_IfDifferentPeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;
        uint256 currentDate = preview.periodDate;

        assertEq(loan.freezeDate, currentDate);
        assertEq(loan.trackedDate, currentDate);

        uint256 skipPeriods = 2;
        skip(loan.periodInSeconds * skipPeriods);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit UnfreezeLoan(loanId, currentDate + loan.periodInSeconds * skipPeriods);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);

        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackedDate, currentDate + loan.periodInSeconds * skipPeriods);
        assertEq(loan.durationInPeriods, oldDurationInPeriods + skipPeriods);
        uint256 newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.unfreeze(NONEXISTENT_LOAN_ID);
    }

    function test_unfreeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        market.unfreeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `updateLoanDuration` function          //
    // -------------------------------------------- //

    function test_updateLoanDuration(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanDuration(loanId, newDurationInPeriods, loan.durationInPeriods);
        market.updateLoanDuration(loanId, newDurationInPeriods);

        loan = market.getLoanState(loanId);
        assertEq(loan.durationInPeriods, newDurationInPeriods);
    }

    function test_updateLoanDuration_IfLender() public {
        test_updateLoanDuration(LENDER_1);
    }

    function test_updateLoanDuration_IfLenderAlias() public {
        test_updateLoanDuration(LENDER_1_ALIAS);
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.prank(OWNER);
        market.pause();

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        uint256 newDurationInPeriods = 2;
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanDuration(NONEXISTENT_LOAN_ID, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfSameLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfDecreasedLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `updateLoanMoratorium` function        //
    // -------------------------------------------- //

    function test_updateLoanMoratorium(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 currentMoratoriumInPeriods = getMoratoriumInPeriods(loanId);
        assertEq(currentMoratoriumInPeriods, 0);

        // Set initial moratorium

        uint256 newMoratoriumInPeriods = 2;
        uint256 newTrackDate = loan.trackedDate + newMoratoriumInPeriods * loan.periodInSeconds;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanMoratorium(loanId, loan.trackedDate, newMoratoriumInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoanState(loanId);
        currentMoratoriumInPeriods = getMoratoriumInPeriods(loanId);

        assertEq(currentMoratoriumInPeriods, newMoratoriumInPeriods);
        assertEq(loan.trackedDate, newTrackDate);

        // Increase moratorium by 1 period

        newMoratoriumInPeriods += 1;
        uint256 increaseInPeriods = newMoratoriumInPeriods - currentMoratoriumInPeriods;
        newTrackDate = loan.trackedDate + increaseInPeriods * loan.periodInSeconds;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanMoratorium(loanId, loan.trackedDate, increaseInPeriods);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);

        loan = market.getLoanState(loanId);
        assertEq(loan.trackedDate, newTrackDate);
        assertEq(getMoratoriumInPeriods(loanId), newMoratoriumInPeriods);
    }

    function test_updateLoanMoratorium_IfLender() public {
        test_updateLoanMoratorium(LENDER_1);
    }

    function test_updateLoanMoratorium_IfLenderAlias() public {
        test_updateLoanMoratorium(LENDER_1_ALIAS);
    }

    function test_updateLoanMoratorium_Flow() public {
        configureMarket();
        uint256 loanId = createActiveLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 skipPeriods = 2;
        uint256 addonPeriods = 3;
        uint256 moratoriumInPeriods = 4;

        assertEq(getMoratoriumInPeriods(loanId), 0);

        vm.prank(LENDER_1);
        market.updateLoanMoratorium(loanId, moratoriumInPeriods);
        assertEq(getMoratoriumInPeriods(loanId), moratoriumInPeriods);

        skip(loan.periodInSeconds * skipPeriods);
        assertEq(getMoratoriumInPeriods(loanId), moratoriumInPeriods - skipPeriods);

        vm.prank(LENDER_1);
        market.updateLoanMoratorium(loanId, moratoriumInPeriods + addonPeriods);
        assertEq(getMoratoriumInPeriods(loanId), moratoriumInPeriods + addonPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(OWNER);
        market.pause();

        uint256 moratoriumInPeriods = 2;

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanMoratorium(loanId, moratoriumInPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        uint256 moratoriumInPeriods = 2;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanMoratorium(loanId, moratoriumInPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        uint256 moratoriumInPeriods = 2;
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanMoratorium(NONEXISTENT_LOAN_ID, moratoriumInPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        uint256 moratoriumInPeriods = 2;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanMoratorium(loanId, moratoriumInPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfSameLoanMoratorium() public {
        configureMarket();
        uint256 loanId = createActiveLoan(0);

        uint256 currentMoratoriumInPeriods = getMoratoriumInPeriods(loanId);
        uint256 newMoratoriumInPeriods = currentMoratoriumInPeriods + 2;

        vm.startPrank(LENDER_1);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);
        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);
    }

    function test_updateLoanMoratorium_Revert_IfDecreasedLoanMoratorium() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        uint256 currentMoratoriumInPeriods = getMoratoriumInPeriods(loanId);
        uint256 newMoratoriumInPeriods = currentMoratoriumInPeriods + 2;

        vm.startPrank(LENDER_1);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods);
        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        market.updateLoanMoratorium(loanId, newMoratoriumInPeriods - 1);
    }

    function getMoratoriumInPeriods(uint256 loanId) private view returns (uint256) {
        Loan.State memory loan = market.getLoanState(loanId);
        uint256 currentDate = market.calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        return loan.trackedDate > currentDate ? (loan.trackedDate - currentDate) / loan.periodInSeconds : 0;
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRatePrimary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRatePrimary(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRatePrimary = loan.interestRatePrimary;
        uint256 newInterestRatePrimary = oldInterestRatePrimary - 1;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanInterestRatePrimary(loanId, newInterestRatePrimary, oldInterestRatePrimary);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRatePrimary, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_IfLender() public {
        test_updateLoanInterestRatePrimary(LENDER_1);
    }

    function test_updateLoanInterestRatePrimary_IfLenderAlias() public {
        test_updateLoanInterestRatePrimary(LENDER_1_ALIAS);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRatePrimary(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfIncreasedInterestRate() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRateSecondary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRateSecondary(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRateSecondary = loan.interestRateSecondary;
        uint256 newInterestRateSecondary = oldInterestRateSecondary - 1;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit UpdateLoanInterestRateSecondary(loanId, newInterestRateSecondary, oldInterestRateSecondary);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRateSecondary, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_IfLender() public {
        test_updateLoanInterestRateSecondary(LENDER_1);
    }

    function test_updateLoanInterestRateSecondary_IfLenderAlias() public {
        test_updateLoanInterestRateSecondary(LENDER_1_ALIAS);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRateSecondary(NONEXISTENT_LOAN_ID, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfIncreasedInterestRate() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    // -------------------------------------------- //
    //  Test `configureAlias` function              //
    // -------------------------------------------- //

    function test_configureAlias() public {
        configureMarket();

        vm.startPrank(LENDER_1);

        vm.expectEmit(true, true, true, true, address(market));
        emit ConfigureLenderAlias(LENDER_1, LENDER_1_ALIAS, false);
        market.configureAlias(LENDER_1_ALIAS, false);
        assertEq(market.hasAlias(LENDER_1, LENDER_1_ALIAS), false);

        vm.expectEmit(true, true, true, true, address(market));
        emit ConfigureLenderAlias(LENDER_1, LENDER_1_ALIAS, true);
        market.configureAlias(LENDER_1_ALIAS, true);
        assertEq(market.hasAlias(LENDER_1, LENDER_1_ALIAS), true);
    }

    function test_configureAlias_Revert_IfContractIsPaused() public {
        configureMarket();

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.configureAlias(LENDER_1_ALIAS, true);
    }

    function test_configureAlias_Revert_IfAliasIsZeroAddress() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.configureAlias(address(0), true);
    }

    function test_configureAlias_Revert_IfAliasIsAlreadyConfigured() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.configureAlias(LENDER_1_ALIAS, true);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getCreditLineLender() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_getLiquidityPoolLender() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(REGISTRY_1);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_calculatePeriodDate_1_Second_Period() public {
        skip(10 ** 6 - 1);

        uint256 periodInSeconds = 1 seconds;
        uint256 currentPeriodSeconds = block.timestamp % periodInSeconds;
        uint256 currentDate = market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0);

        skip(periodInSeconds - currentPeriodSeconds - 1);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentDate);

        skip(1);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 2, 0), currentDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 3), currentDate + periodInSeconds + 3);
    }

    function test_calculatePeriodDate_59_Second_Period() public {
        skip(10 ** 6 - 1);

        uint256 periodInSeconds = 59 seconds;
        uint256 currentPeriodSeconds = block.timestamp % periodInSeconds;
        uint256 currentDate = market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0);

        skip(periodInSeconds - currentPeriodSeconds - 1);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentDate);

        skip(1);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 0), currentDate + periodInSeconds);

        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 2, 0), currentDate + periodInSeconds * 3);
        assertEq(market.calculatePeriodDate(block.timestamp, periodInSeconds, 0, 3), currentDate + periodInSeconds + 3);
    }

    // -------------------------------------------- //
    //  ERC165 support                              //
    // -------------------------------------------- //

    function test_supportsInterface() public {
        assertEq(market.supportsInterface(0x0), false);
        assertEq(market.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(market.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(market.supportsInterface(0x5b5e139f), true); // ERC721Metadata
        assertEq(market.supportsInterface(0x780e9d63), true); // ERC721Enumerable
    }
}

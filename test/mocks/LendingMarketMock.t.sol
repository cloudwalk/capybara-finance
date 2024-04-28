// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";

import { LendingMarketMock } from "src/mocks/LendingMarketMock.sol";

/// @title LendingMarketMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LendingMarketMock` contract.
contract LendingMarketMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);

    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);

    event RepayLoanCalled(uint256 indexed loanId, uint256 repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LendingMarketMock private mock;

    address private constant TOKEN = address(bytes20(keccak256("token")));
    address private constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address private constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address private constant TREASURY = address(bytes20(keccak256("treasury")));
    address private constant BORROWER = address(bytes20(keccak256("borrower")));
    address private constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    address private constant LIQUIDITY_POOL = address(bytes20(keccak256("liquidity_pool")));

    uint256 private constant DURATION_IN_PERIODS = 30;
    uint256 private constant BORROW_AMOUNT = 100;
    uint256 private constant REPAY_AMOUNT = 200;
    uint256 private constant LOAN_ID = 1;

    uint16 private constant STATE_REVOCATION_PERIODS = 10;
    uint32 private constant STATE_DURATION_IN_PERIODS = 200;
    uint32 private constant STATE_INTEREST_RATE_PRIMARY = 400;
    uint32 private constant STATE_INTEREST_RATE_SECONDARY = 500;
    Interest.Formula private constant STATE_INTEREST_FORMULA = Interest.Formula.Compound;
    uint32 private constant STATE_START_TIMESTAMP = 600;
    uint32 private constant STATE_FREEZE_TIMESTAMP = 700;
    uint32 private constant STATE_TRACKED_TIMESTAMP = 800;
    uint64 private constant STATE_INITIAL_BORROW_AMOUNT = 900;
    uint64 private constant STATE_TRACKED_BORROW_BALANCE = 1000;
    uint64 private constant STATE_ADDON_AMOUNT = 1100;
    bool private constant STATE_AUTO_REPAYMENT = true;

    uint256 private constant UPDATE_LOAN_DURATION = 100;
    uint256 private constant UPDATE_LOAN_INTEREST_RATE_PRIMARY = 300;
    uint256 private constant UPDATE_LOAN_INTEREST_RATE_SECONDARY = 400;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new LendingMarketMock();
    }

    // -------------------------------------------- //
    //  ILendingMarket functions                    //
    // -------------------------------------------- //

    function test_takeLoan() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.takeLoan(CREDIT_LINE, BORROW_AMOUNT, DURATION_IN_PERIODS);
    }

    function test_repayLoan() public {
        vm.prank(address(mock));
        vm.expectEmit(true, true, true, true, address(mock));
        emit RepayLoanCalled(LOAN_ID, REPAY_AMOUNT);
        mock.repayLoan(LOAN_ID, REPAY_AMOUNT);
    }

    function test_revokeLoan() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.revokeLoan(LOAN_ID);
    }

    function test_freeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.freeze(LOAN_ID);
    }

    function test_unfreeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.unfreeze(LOAN_ID);
    }

    function test_updateLoanDuration() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanDuration(LOAN_ID, UPDATE_LOAN_DURATION);
    }

    function test_updateLoanInterestRatePrimary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanInterestRatePrimary(LOAN_ID, UPDATE_LOAN_INTEREST_RATE_PRIMARY);
    }

    function test_updateLoanInterestRateSecondary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanInterestRateSecondary(LOAN_ID, UPDATE_LOAN_INTEREST_RATE_SECONDARY);
    }

    function test_registerCreditLine() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit RegisterCreditLineCalled(LENDER_1, CREDIT_LINE);
        mock.registerCreditLine(LENDER_1, CREDIT_LINE);
    }

    function test_registerLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit RegisterLiquidityPoolCalled(LENDER_1, LIQUIDITY_POOL);
        mock.registerLiquidityPool(LENDER_1, LIQUIDITY_POOL);
    }

    function test_updateCreditLineLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateCreditLineLender(CREDIT_LINE, LENDER_1);
    }

    function test_updateLiquidityPoolLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLiquidityPoolLender(LIQUIDITY_POOL, LENDER_1);
    }

    function test_assignLiquidityPoolToCreditLine() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.assignLiquidityPoolToCreditLine(CREDIT_LINE, LIQUIDITY_POOL);
    }

    function test_configureAlias() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.configureAlias(LENDER_2, true);
    }

    function test_getCreditLineLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getCreditLineLender(CREDIT_LINE);
    }

    function test_getLiquidityPoolLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLiquidityPoolLender(LIQUIDITY_POOL);
    }

    function test_getLiquidityPoolByCreditLine() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLiquidityPoolByCreditLine(CREDIT_LINE);
    }

    function test_getLoanState() public {
        Loan.State memory loan = mock.getLoanState(LOAN_ID);

        assertEq(loan.token, address(0));
        assertEq(loan.borrower, address(0));
        assertEq(loan.treasury, address(0));
        assertEq(loan.durationInPeriods, 0);
        assertEq(loan.interestRatePrimary, 0);
        assertEq(loan.interestRateSecondary, 0);
        assertEq(uint256(loan.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(loan.startTimestamp, 0);
        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.trackedTimestamp, 0);
        assertEq(loan.initialBorrowAmount, 0);
        assertEq(loan.trackedBorrowBalance, 0);
        assertEq(loan.autoRepayment, false);
        assertEq(loan.revocationPeriods, 0);
        assertEq(loan.addonAmount, 0);

        mock.mockLoanState(
            1,
            Loan.State({
                token: TOKEN,
                borrower: BORROWER,
                treasury: TREASURY,
                durationInPeriods: STATE_DURATION_IN_PERIODS,
                interestRatePrimary: STATE_INTEREST_RATE_PRIMARY,
                interestRateSecondary: STATE_INTEREST_RATE_SECONDARY,
                interestFormula: STATE_INTEREST_FORMULA,
                startTimestamp: STATE_START_TIMESTAMP,
                freezeTimestamp: STATE_FREEZE_TIMESTAMP,
                trackedTimestamp: STATE_TRACKED_TIMESTAMP,
                initialBorrowAmount: STATE_INITIAL_BORROW_AMOUNT,
                trackedBorrowBalance: STATE_TRACKED_BORROW_BALANCE,
                autoRepayment: STATE_AUTO_REPAYMENT,
                revocationPeriods: STATE_REVOCATION_PERIODS,
                addonAmount: STATE_ADDON_AMOUNT
            })
        );

        loan = mock.getLoanState(LOAN_ID);

        assertEq(loan.token, TOKEN);
        assertEq(loan.borrower, BORROWER);
        assertEq(loan.treasury, TREASURY);
        assertEq(loan.durationInPeriods, STATE_DURATION_IN_PERIODS);
        assertEq(loan.interestRatePrimary, STATE_INTEREST_RATE_PRIMARY);
        assertEq(loan.interestRateSecondary, STATE_INTEREST_RATE_SECONDARY);
        assertEq(uint256(loan.interestFormula), uint256(STATE_INTEREST_FORMULA));
        assertEq(loan.startTimestamp, STATE_START_TIMESTAMP);
        assertEq(loan.freezeTimestamp, STATE_FREEZE_TIMESTAMP);
        assertEq(loan.trackedTimestamp, STATE_TRACKED_TIMESTAMP);
        assertEq(loan.initialBorrowAmount, STATE_INITIAL_BORROW_AMOUNT);
        assertEq(loan.trackedBorrowBalance, STATE_TRACKED_BORROW_BALANCE);
        assertEq(loan.autoRepayment, STATE_AUTO_REPAYMENT);
        assertEq(loan.revocationPeriods, STATE_REVOCATION_PERIODS);
        assertEq(loan.addonAmount, STATE_ADDON_AMOUNT);
    }

    function test_getLoanPreview() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLoanPreview(LOAN_ID, 0);
    }

    function test_hasAlias() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.hasAlias(LENDER_1, LENDER_2);
    }

    function test_registry() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.registry();
    }
}

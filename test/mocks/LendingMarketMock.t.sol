// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/libraries/Loan.sol";
import { Error } from "src/libraries/Error.sol";
import { Interest } from "src/libraries/Interest.sol";

import { LendingMarketMock } from "src/mocks/LendingMarketMock.sol";

/// @title LendingMarketMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LendingMarketMock` contract.
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

    LendingMarketMock public mock;

    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant TREASURY = address(bytes20(keccak256("treasury")));
    address public constant BORROWER = address(bytes20(keccak256("borrower")));
    address public constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    address public constant LIQUIDITY_POOL = address(bytes20(keccak256("liquidity_pool")));

    uint256 public constant LOAN_ID = 1;
    uint256 public constant BORROW_AMOUNT = 100;
    uint256 public constant REPAY_AMOUNT = 200;

    uint32 public constant STATE_PERIOD_IN_SECONDS = 100;
    uint32 public constant STATE_DURATION_IN_PERIODS = 200;
    uint32 public constant STATE_INTEREST_RATE_FACTOR = 300;
    uint32 public constant STATE_INTEREST_RATE_PRIMARY = 400;
    uint32 public constant STATE_INTEREST_RATE_SECONDARY = 500;
    Interest.Formula public constant STATE_INTEREST_FORMULA = Interest.Formula.Compound;
    uint32 public constant STATE_START_DATE = 600;
    uint32 public constant STATE_FREEZE_DATE = 700;
    uint32 public constant STATE_TRACKED_DATE = 800;
    uint64 public constant STATE_INITIAL_BORROW_AMOUNT = 900;
    uint64 public constant STATE_TRACKED_BORROW_BALANCE = 1000;
    bool public constant STATE_AUTO_REPAYMENT = true;

    uint256 public constant UPDATE_LOAN_DURATION = 100;
    uint256 public constant UPDATE_LOAN_MORATORIUM = 200;
    uint256 public constant UPDATE_LOAN_INTEREST_RATE_PRIMARY = 300;
    uint256 public constant UPDATE_LOAN_INTEREST_RATE_SECONDARY = 400;

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
        mock.takeLoan(CREDIT_LINE, BORROW_AMOUNT);
    }

    function test_repayLoan() public {
        vm.prank(address(mock));
        vm.expectEmit(true, true, true, true, address(mock));
        emit RepayLoanCalled(LOAN_ID, REPAY_AMOUNT);
        mock.repayLoan(LOAN_ID, REPAY_AMOUNT);
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

    function test_updateLoanMoratorium() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanMoratorium(LOAN_ID, UPDATE_LOAN_MORATORIUM);
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
        emit RegisterCreditLineCalled(LENDER, CREDIT_LINE);
        mock.registerCreditLine(LENDER, CREDIT_LINE);
    }

    function test_registerLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit RegisterLiquidityPoolCalled(LENDER, LIQUIDITY_POOL);
        mock.registerLiquidityPool(LENDER, LIQUIDITY_POOL);
    }

    function test_getCreditLineLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getCreditLineLender(CREDIT_LINE);
    }

    function test_getLiquidityPoolLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLiquidityPoolLender(LIQUIDITY_POOL);
    }

    function test_getLoanState() public {
        Loan.State memory loan = mock.getLoanState(LOAN_ID);

        assertEq(loan.token, address(0));
        assertEq(loan.borrower, address(0));
        assertEq(loan.treasury, address(0));
        assertEq(loan.periodInSeconds, 0);
        assertEq(loan.durationInPeriods, 0);
        assertEq(loan.interestRateFactor, 0);
        assertEq(loan.interestRatePrimary, 0);
        assertEq(loan.interestRateSecondary, 0);
        assertEq(uint256(loan.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(loan.startDate, 0);
        assertEq(loan.freezeDate, 0);
        assertEq(loan.trackedDate, 0);
        assertEq(loan.initialBorrowAmount, 0);
        assertEq(loan.trackedBorrowBalance, 0);
        assertEq(loan.autoRepayment, false);

        mock.mockLoanState(
            1,
            Loan.State({
                token: TOKEN,
                borrower: BORROWER,
                treasury: TREASURY,
                periodInSeconds: STATE_PERIOD_IN_SECONDS,
                durationInPeriods: STATE_DURATION_IN_PERIODS,
                interestRateFactor: STATE_INTEREST_RATE_FACTOR,
                interestRatePrimary: STATE_INTEREST_RATE_PRIMARY,
                interestRateSecondary: STATE_INTEREST_RATE_SECONDARY,
                interestFormula: STATE_INTEREST_FORMULA,
                startDate: STATE_START_DATE,
                freezeDate: STATE_FREEZE_DATE,
                trackedDate: STATE_TRACKED_DATE,
                initialBorrowAmount: STATE_INITIAL_BORROW_AMOUNT,
                trackedBorrowBalance: STATE_TRACKED_BORROW_BALANCE,
                autoRepayment: STATE_AUTO_REPAYMENT
            })
        );

        loan = mock.getLoanState(LOAN_ID);

        assertEq(loan.token, TOKEN);
        assertEq(loan.borrower, BORROWER);
        assertEq(loan.treasury, TREASURY);
        assertEq(loan.periodInSeconds, STATE_PERIOD_IN_SECONDS);
        assertEq(loan.durationInPeriods, STATE_DURATION_IN_PERIODS);
        assertEq(loan.interestRateFactor, STATE_INTEREST_RATE_FACTOR);
        assertEq(loan.interestRatePrimary, STATE_INTEREST_RATE_PRIMARY);
        assertEq(loan.interestRateSecondary, STATE_INTEREST_RATE_SECONDARY);
        assertEq(uint256(loan.interestFormula), uint256(STATE_INTEREST_FORMULA));
        assertEq(loan.startDate, STATE_START_DATE);
        assertEq(loan.freezeDate, STATE_FREEZE_DATE);
        assertEq(loan.trackedDate, STATE_TRACKED_DATE);
        assertEq(loan.initialBorrowAmount, STATE_INITIAL_BORROW_AMOUNT);
        assertEq(loan.trackedBorrowBalance, STATE_TRACKED_BORROW_BALANCE);
        assertEq(loan.autoRepayment, STATE_AUTO_REPAYMENT);
    }

    function test_getLoanPreview() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLoanPreview(LOAN_ID, 0);
    }

    function test_registry() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.registry();
    }
}

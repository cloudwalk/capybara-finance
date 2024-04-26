// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";

import { LiquidityPoolMock } from "src/mocks/LiquidityPoolMock.sol";

/// @title LiquidityPoolMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolMock` contract.
contract LiquidityPoolMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed LiquidityPool);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed LiquidityPool);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnBeforeLoanRevokeCalled(uint256 indexed loanId);
    event OnAfterLoanRevokeCalled(uint256 indexed loanId);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolMock private mock;

    uint256 private constant LOAN_ID = 1;
    uint256 private constant REPAY_AMOUNT = 100;
    address private constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new LiquidityPoolMock();
    }

    // -------------------------------------------- //
    //  ILiquidityPoolFactory functions             //
    // -------------------------------------------- //

    function test_onBeforeLoanTaken() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanTakenCalled(LOAN_ID, CREDIT_LINE);
        bool result = mock.onBeforeLoanTaken(LOAN_ID, CREDIT_LINE);
        assertEq(result, false);

        mock.mockOnBeforeLoanTakenResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanTakenCalled(LOAN_ID, CREDIT_LINE);
        result = mock.onBeforeLoanTaken(LOAN_ID, CREDIT_LINE);
        assertEq(result, true);
    }

    function test_onAfterLoanTaken() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanTakenCalled(LOAN_ID, CREDIT_LINE);
        bool result = mock.onAfterLoanTaken(LOAN_ID, CREDIT_LINE);
        assertEq(result, false);

        mock.mockOnAfterLoanTakenResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanTakenCalled(LOAN_ID, CREDIT_LINE);
        result = mock.onAfterLoanTaken(LOAN_ID, CREDIT_LINE);
        assertEq(result, true);
    }

    function test_onBeforeLoanPayment() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanPaymentCalled(LOAN_ID, REPAY_AMOUNT);
        bool result = mock.onBeforeLoanPayment(LOAN_ID, REPAY_AMOUNT);
        assertEq(result, false);

        mock.mockOnBeforeLoanPaymentResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanPaymentCalled(LOAN_ID, REPAY_AMOUNT);
        result = mock.onBeforeLoanPayment(LOAN_ID, REPAY_AMOUNT);
        assertEq(result, true);
    }

    function test_onAfterLoanPayment() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanPaymentCalled(LOAN_ID, REPAY_AMOUNT);
        bool result = mock.onAfterLoanPayment(LOAN_ID, REPAY_AMOUNT);
        assertEq(result, false);

        mock.mockOnAfterLoanPaymentResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanPaymentCalled(LOAN_ID, REPAY_AMOUNT);
        result = mock.onAfterLoanPayment(LOAN_ID, REPAY_AMOUNT);
        assertEq(result, true);
    }

    function test_onBeforeLoanRevoke() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanRevokeCalled(LOAN_ID);
        bool result = mock.onBeforeLoanRevoke(LOAN_ID);
        assertEq(result, false);

        mock.mockOnBeforeLoanRevokeResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanRevokeCalled(LOAN_ID);
        result = mock.onBeforeLoanRevoke(LOAN_ID);
        assertEq(result, true);
    }

    function test_onAfterLoanRevoke() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanRevokeCalled(LOAN_ID);
        bool result = mock.onAfterLoanRevoke(LOAN_ID);
        assertEq(result, false);

        mock.mockOnAfterLoanRevokeResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanRevokeCalled(LOAN_ID);
        result = mock.onAfterLoanRevoke(LOAN_ID);
        assertEq(result, true);
    }

    function test_market() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.market();
    }

    function test_lender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.lender();
    }

    function test_kind() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.kind();
    }
}

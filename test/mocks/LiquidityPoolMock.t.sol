// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";

import { LiquidityPoolMock } from "src/mocks/LiquidityPoolMock.sol";

/// @title LiquidityPoolMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolMock` contract.
contract LiquidityPoolMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed LiquidityPool);

    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnAfterLoanRevocationCalled(uint256 indexed loanId);

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
    //  ILiquidityPool functions                    //
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

    function test_onAfterLoanRevocation() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanRevocationCalled(LOAN_ID);
        bool result = mock.onAfterLoanRevocation(LOAN_ID);
        assertEq(result, false);

        mock.mockOnAfterLoanRevocationResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanRevocationCalled(LOAN_ID);
        result = mock.onAfterLoanRevocation(LOAN_ID);
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
}

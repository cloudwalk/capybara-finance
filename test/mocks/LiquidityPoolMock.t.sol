// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LiquidityPoolMock} from "src/mocks/LiquidityPoolMock.sol";

/// @title LiquidityPoolMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LiquidityPoolMock` contract
contract LiquidityPoolMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed LiquidityPool);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed LiquidityPool);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolMock public mock;

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
        emit OnBeforeLoanTakenCalled(100, address(0x1));
        bool result = mock.onBeforeLoanTaken(100, address(0x1));
        assertEq(result, false);

        mock.mockOnBeforeLoanTakenResult(true);
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanTakenCalled(100, address(0x1));
        result = mock.onBeforeLoanTaken(100, address(0x1));
        assertEq(result, true);
    }

    function test_onAfterLoanTaken() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanTakenCalled(100, address(0x1));
        bool result = mock.onAfterLoanTaken(100, address(0x1));
        assertEq(result, false);

        mock.mockOnAfterLoanTakenResult(true);
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanTakenCalled(100, address(0x1));
        result = mock.onAfterLoanTaken(100, address(0x1));
        assertEq(result, true);
    }

    function test_onBeforeLoanPayment() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanPaymentCalled(100, 100);
        bool result = mock.onBeforeLoanPayment(100, 100);
        assertEq(result, false);

        mock.mockOnBeforeLoanPaymentResult(true);
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanPaymentCalled(100, 100);
        result = mock.onBeforeLoanPayment(100, 100);
        assertEq(result, true);
    }

    function test_onAfterLoanPayment() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanPaymentCalled(100, 100);
        bool result = mock.onAfterLoanPayment(100, 100);
        assertEq(result, false);

        mock.mockOnAfterLoanPaymentResult(true);
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnAfterLoanPaymentCalled(100, 100);
        result = mock.onAfterLoanPayment(100, 100);
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

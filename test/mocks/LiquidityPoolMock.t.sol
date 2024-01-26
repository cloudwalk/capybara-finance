// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {LiquidityPoolMock} from "src/mocks/LiquidityPoolMock.sol";
import {Error} from "src/libraries/Error.sol";

/// @title LiquidityPoolMockTest contract
/// @notice Contains tests for the LiquidityPoolMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolMockTest is Test {

    event OnBeforeTakeLoanCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterTakeLoanCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);


    address public constant OWNER = address(bytes20(keccak256("OWNER")));
    address public constant CREDIT_LINE = address(bytes20(keccak256("CREDIT_LINE")));
    uint256 public constant LOAN_ID = 1;
    uint256 public constant AMOUNT = 1000;
    bool public constant TRUE_VALUE = true;

    LiquidityPoolMock public liquidityPoolMock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        liquidityPoolMock = new LiquidityPoolMock();

        vm.stopPrank();
    }

    /************************************************
     *  Test `mockOnBeforeTakeLoanResult/onBeforeTakeLoan` function
     ***********************************************/

    function test_mockOnBeforeTakeLoanResult_onBeforeTakeLoan() public {
        liquidityPoolMock.mockOnBeforeTakeLoanResult(TRUE_VALUE);

        vm.expectEmit(true, true, true, true, address(liquidityPoolMock));
        emit OnBeforeTakeLoanCalled(LOAN_ID, CREDIT_LINE);
        bool res = liquidityPoolMock.onBeforeTakeLoan(LOAN_ID, CREDIT_LINE);

        assertEq(res, TRUE_VALUE);
    }

    /************************************************
     *  Test `mockOnAfterTakeLoanResult/onAfterTakeLoan` function
     ***********************************************/

    function test_mockOnAfterTakeLoanResult_onAfterTakeLoan() public {
        liquidityPoolMock.mockOnAfterTakeLoanResult(TRUE_VALUE);

        vm.expectEmit(true, true, true, true, address(liquidityPoolMock));
        emit OnAfterTakeLoanCalled(LOAN_ID, CREDIT_LINE);
        bool res = liquidityPoolMock.onAfterTakeLoan(LOAN_ID, CREDIT_LINE);

        assertEq(res, TRUE_VALUE);
    }

    /************************************************
     *  Test `mockOnBeforeLoanPaymentResult/onBeforeLoanPayment` function
     ***********************************************/

    function test_mockOnBeforeLoanPaymentResult_onBeforeLoanPayment() public {
        liquidityPoolMock.mockOnBeforeLoanPaymentResult(TRUE_VALUE);

        vm.expectEmit(true, true, true, true, address(liquidityPoolMock));
        emit OnBeforeLoanPaymentCalled(LOAN_ID, AMOUNT);
        bool res = liquidityPoolMock.onBeforeLoanPayment(LOAN_ID, AMOUNT);

        assertEq(res, TRUE_VALUE);
    }

    /************************************************
     *  Test `mockOnAfterLoanPaymentResult/onAfterLoanPayment` function
     ***********************************************/

    function test_mockOnAfterLoanPaymentResult() public {
        liquidityPoolMock.mockOnAfterLoanPaymentResult(TRUE_VALUE);

        vm.expectEmit(true, true, true, true, address(liquidityPoolMock));
        emit OnAfterLoanPaymentCalled(LOAN_ID, AMOUNT);
        bool res = liquidityPoolMock.onAfterLoanPayment(LOAN_ID, AMOUNT);

        assertEq(res, TRUE_VALUE);
    }

    /************************************************
     *  Test `market` function
     ***********************************************/

    function test_market() public {
        vm.expectRevert(Error.NotImplemented.selector);
        liquidityPoolMock.market();
    }

    /************************************************
     *  Test `lender` function
     ***********************************************/

    function test_lender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        liquidityPoolMock.lender();
    }

    /************************************************
     *  Test `kind` function
     ***********************************************/

    function test_kind() public {
        vm.expectRevert(Error.NotImplemented.selector);
        liquidityPoolMock.kind();
    }
}

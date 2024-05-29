// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";

import { CreditLineMock } from "src/mocks/CreditLineMock.sol";

/// @title CreditLineMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `CreditLineMock` contract.
contract CreditLineMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId);

    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnAfterLoanRevocationCalled(uint256 indexed loanId);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineMock private mock;

    uint256 private constant LOAN_ID = 1;
    uint256 private constant BORROW_AMOUNT = 100;
    uint256 private constant REPAY_AMOUNT = 100;
    uint256 private constant DURATION_IN_PERIODS = 30;
    address private constant BORROWER = address(bytes20(keccak256("borrower")));

    address private constant TERMS_TOKEN = address(bytes20(keccak256("token")));

    uint32 private constant TERMS_DURATION_IN_PERIODS = 200;
    uint32 private constant TERMS_INTEREST_RATE_PRIMARY = 400;
    uint32 private constant TERMS_INTEREST_RATE_SECONDARY = 500;
    uint32 private constant TERMS_ADDON_AMOUNT = 600;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new CreditLineMock();
    }

    // -------------------------------------------- //
    //  ICreditLine functions                       //
    // -------------------------------------------- //

    function test_determineLoanTerms() public {
        Loan.Terms memory terms = mock.determineLoanTerms(BORROWER, BORROW_AMOUNT, DURATION_IN_PERIODS);

        assertEq(terms.token, address(0));
        assertEq(terms.durationInPeriods, 0);
        assertEq(terms.interestRatePrimary, 0);
        assertEq(terms.interestRateSecondary, 0);
        assertEq(terms.addonAmount, 0);

        mock.mockLoanTerms(
            BORROWER,
            BORROW_AMOUNT,
            Loan.Terms({
                token: TERMS_TOKEN,
                durationInPeriods: TERMS_DURATION_IN_PERIODS,
                interestRatePrimary: TERMS_INTEREST_RATE_PRIMARY,
                interestRateSecondary: TERMS_INTEREST_RATE_SECONDARY,
                addonAmount: TERMS_ADDON_AMOUNT
            })
        );

        terms = mock.determineLoanTerms(BORROWER, BORROW_AMOUNT, DURATION_IN_PERIODS);

        assertEq(terms.token, TERMS_TOKEN);
        assertEq(terms.durationInPeriods, TERMS_DURATION_IN_PERIODS);
        assertEq(terms.interestRatePrimary, TERMS_INTEREST_RATE_PRIMARY);
        assertEq(terms.interestRateSecondary, TERMS_INTEREST_RATE_SECONDARY);
        assertEq(terms.addonAmount, TERMS_ADDON_AMOUNT);
    }

    function test_onBeforeLoanTaken() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanTakenCalled(LOAN_ID);
        bool result = mock.onBeforeLoanTaken(LOAN_ID);
        assertEq(result, false);

        mock.mockOnBeforeLoanTakenResult(true);

        vm.expectEmit(true, true, true, true, address(mock));
        emit OnBeforeLoanTakenCalled(LOAN_ID);
        result = mock.onBeforeLoanTaken(LOAN_ID);
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

    function test_token() public {
        assertEq(mock.token(), address(0));
        mock.mockTokenAddress(TERMS_TOKEN);
        assertEq(mock.token(), TERMS_TOKEN);
    }
}

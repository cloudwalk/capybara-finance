// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Loan } from "src/libraries/Loan.sol";
import { Error } from "src/libraries/Error.sol";
import { Interest } from "src/libraries/Interest.sol";

import { CreditLineMock } from "src/mocks/CreditLineMock.sol";

/// @title CreditLineMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `CreditLineMock` contract.
contract CreditLineMockTest is Test {
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineMock public mock;

    uint256 public constant LOAN_ID = 1;
    uint256 public constant BORROW_AMOUNT = 100;
    uint256 public constant DURATION_IN_PERIODS = 30;
    address public constant BORROWER = address(bytes20(keccak256("borrower")));

    address public constant TERMS_TOKEN = address(bytes20(keccak256("token")));
    address public constant TERMS_TREASURY = address(bytes20(keccak256("treasury")));
    address public constant TERMS_ADDON_RECIPIENT = address(bytes20(keccak256("addon")));

    uint32 public constant TERMS_PERIOD_IN_SECONDS = 100;
    uint32 public constant TERMS_DURATION_IN_PERIODS = 200;
    uint32 public constant TERMS_INTEREST_RATE_FACTOR = 300;
    uint32 public constant TERMS_INTEREST_RATE_PRIMARY = 400;
    uint32 public constant TERMS_INTEREST_RATE_SECONDARY = 500;
    uint32 public constant TERMS_ADDON_AMOUNT = 600;

    Interest.Formula public constant TERMS_INTEREST_FORMULA = Interest.Formula.Compound;
    bool public constant TERMS_AUTO_REPAYMENT = true;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new CreditLineMock();
    }

    // -------------------------------------------- //
    //  ICreditLineFactory functions                //
    // -------------------------------------------- //

    function test_onBeforeLoanTaken() public {
        Loan.Terms memory terms = mock.onBeforeLoanTaken(BORROWER, DURATION_IN_PERIODS, BORROW_AMOUNT, LOAN_ID);

        assertEq(terms.token, address(0));
        assertEq(terms.treasury, address(0));
        assertEq(terms.periodInSeconds, 0);
        assertEq(terms.durationInPeriods, 0);
        assertEq(terms.interestRateFactor, 0);
        assertEq(terms.interestRatePrimary, 0);
        assertEq(terms.interestRateSecondary, 0);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(terms.addonRecipient, address(0));
        assertEq(terms.autoRepayment, false);
        assertEq(terms.addonAmount, 0);

        mock.mockLoanTerms(
            BORROWER,
            BORROW_AMOUNT,
            Loan.Terms({
                token: TERMS_TOKEN,
                treasury: TERMS_TREASURY,
                periodInSeconds: TERMS_PERIOD_IN_SECONDS,
                durationInPeriods: TERMS_DURATION_IN_PERIODS,
                interestRateFactor: TERMS_INTEREST_RATE_FACTOR,
                interestRatePrimary: TERMS_INTEREST_RATE_PRIMARY,
                interestRateSecondary: TERMS_INTEREST_RATE_SECONDARY,
                interestFormula: TERMS_INTEREST_FORMULA,
                addonRecipient: TERMS_ADDON_RECIPIENT,
                autoRepayment: TERMS_AUTO_REPAYMENT,
                addonAmount: TERMS_ADDON_AMOUNT
            })
        );

        terms = mock.onBeforeLoanTaken(BORROWER, DURATION_IN_PERIODS, BORROW_AMOUNT, LOAN_ID);

        assertEq(terms.token, TERMS_TOKEN);
        assertEq(terms.treasury, TERMS_TREASURY);
        assertEq(terms.periodInSeconds, TERMS_PERIOD_IN_SECONDS);
        assertEq(terms.durationInPeriods, TERMS_DURATION_IN_PERIODS);
        assertEq(terms.interestRateFactor, TERMS_INTEREST_RATE_FACTOR);
        assertEq(terms.interestRatePrimary, TERMS_INTEREST_RATE_PRIMARY);
        assertEq(terms.interestRateSecondary, TERMS_INTEREST_RATE_SECONDARY);
        assertEq(uint256(terms.interestFormula), uint256(TERMS_INTEREST_FORMULA));
        assertEq(terms.addonRecipient, TERMS_ADDON_RECIPIENT);
        assertEq(terms.autoRepayment, TERMS_AUTO_REPAYMENT);
        assertEq(terms.addonAmount, TERMS_ADDON_AMOUNT);
    }

    function test_determineLoanTerms() public {
        Loan.Terms memory terms = mock.determineLoanTerms(BORROWER, DURATION_IN_PERIODS, BORROW_AMOUNT);

        assertEq(terms.token, address(0));
        assertEq(terms.treasury, address(0));
        assertEq(terms.periodInSeconds, 0);
        assertEq(terms.durationInPeriods, 0);
        assertEq(terms.interestRateFactor, 0);
        assertEq(terms.interestRatePrimary, 0);
        assertEq(terms.interestRateSecondary, 0);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(terms.addonRecipient, address(0));
        assertEq(terms.autoRepayment, false);
        assertEq(terms.addonAmount, 0);

        mock.mockLoanTerms(
            BORROWER,
            BORROW_AMOUNT,
            Loan.Terms({
                token: TERMS_TOKEN,
                treasury: TERMS_TREASURY,
                periodInSeconds: TERMS_PERIOD_IN_SECONDS,
                durationInPeriods: TERMS_DURATION_IN_PERIODS,
                interestRateFactor: TERMS_INTEREST_RATE_FACTOR,
                interestRatePrimary: TERMS_INTEREST_RATE_PRIMARY,
                interestRateSecondary: TERMS_INTEREST_RATE_SECONDARY,
                interestFormula: TERMS_INTEREST_FORMULA,
                addonRecipient: TERMS_ADDON_RECIPIENT,
                autoRepayment: TERMS_AUTO_REPAYMENT,
                addonAmount: TERMS_ADDON_AMOUNT
            })
        );

        terms = mock.determineLoanTerms(BORROWER, DURATION_IN_PERIODS, BORROW_AMOUNT);

        assertEq(terms.token, TERMS_TOKEN);
        assertEq(terms.treasury, TERMS_TREASURY);
        assertEq(terms.periodInSeconds, TERMS_PERIOD_IN_SECONDS);
        assertEq(terms.durationInPeriods, TERMS_DURATION_IN_PERIODS);
        assertEq(terms.interestRateFactor, TERMS_INTEREST_RATE_FACTOR);
        assertEq(terms.interestRatePrimary, TERMS_INTEREST_RATE_PRIMARY);
        assertEq(terms.interestRateSecondary, TERMS_INTEREST_RATE_SECONDARY);
        assertEq(uint256(terms.interestFormula), uint256(TERMS_INTEREST_FORMULA));
        assertEq(terms.addonRecipient, TERMS_ADDON_RECIPIENT);
        assertEq(terms.autoRepayment, TERMS_AUTO_REPAYMENT);
        assertEq(terms.addonAmount, TERMS_ADDON_AMOUNT);
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

    function test_kind() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.kind();
    }
}

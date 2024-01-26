// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {CreditLineMock} from "src/mocks/CreditLineMock.sol";
import {Loan} from "src/libraries/Loan.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Error} from "src/libraries/Error.sol";

/// @title CreditLineMock contract
/// @notice Contains tests for the CreditLineMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineMockTest is Test {

    address public constant OWNER = address(bytes20(keccak256("OWNER")));
    address public constant TOKEN = address(bytes20(keccak256("TOKEN")));
    address public constant BORROWER = address(bytes20(keccak256("BORROWER")));

    uint32 public constant MOCK_AMOUNT = 100;

    uint32 public constant INIT_TERMS_PERIOD_IN_SECONDS = 600;
    uint32 public constant INIT_TERMS_DURATION_IN_PERIODS = 50;
    uint32 public constant INIT_TERMS_INTEREST_RATE_FACTOR = 1000;
    address public constant INIT_TERMS_ADDON_RECIPIENT = address(bytes20(keccak256("RECIPIENT")));
    uint64 public constant INIT_TERMS_ADDON_AMOUNT = 1000;
    uint32 public constant INIT_TERMS_INTEREST_RATE_PRIMARY = 7;
    uint32 public constant INIT_TERMS_INTEREST_RATE_SECONDARY = 9;
    bool public constant INIT_TERMS_AUTOREPAYMENT = true;

    CreditLineMock public creditLineMock;
    Loan.Terms public terms;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        creditLineMock = new CreditLineMock();

        vm.stopPrank();
    }

    function initTermsConfig()
        public
        pure
        returns (Loan.Terms memory)
    {
        return Loan.Terms({
            token: TOKEN,
            periodInSeconds: INIT_TERMS_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_TERMS_DURATION_IN_PERIODS,
            interestRateFactor: INIT_TERMS_INTEREST_RATE_FACTOR,
            addonRecipient:INIT_TERMS_ADDON_RECIPIENT,
            addonAmount:INIT_TERMS_ADDON_AMOUNT,
            interestRatePrimary:INIT_TERMS_INTEREST_RATE_PRIMARY,
            interestRateSecondary:INIT_TERMS_INTEREST_RATE_SECONDARY,
            interestFormula: Interest.Formula.Simple,
            autoRepayment: INIT_TERMS_AUTOREPAYMENT
        });
    }

    /************************************************
     *  Test `market` function
     ***********************************************/

    function test_market() public {
        vm.expectRevert(Error.NotImplemented.selector);
        creditLineMock.market();
    }

    /************************************************
     *  Test `lender` function
     ***********************************************/

    function test_lender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        creditLineMock.lender();
    }

    /************************************************
     *  Test `kind` function
     ***********************************************/

    function test_kind() public {
        vm.expectRevert(Error.NotImplemented.selector);
        creditLineMock.kind();
    }

    /************************************************
     *  Test `mockTokenAddress` function
     ***********************************************/

    function test_mockTokenAddress() public {
        creditLineMock.mockTokenAddress(TOKEN);
        assertEq(creditLineMock.token(), TOKEN);
    }

    /************************************************
     *  Test `mockLoanTerms/onTakeLoan` function
     ***********************************************/

    function test_mockLoanTerms_onTakeLoan() public {
        terms = initTermsConfig();

        creditLineMock.mockLoanTerms(BORROWER, MOCK_AMOUNT, terms);
        Loan.Terms memory mockTerms = creditLineMock.onTakeLoan(BORROWER, MOCK_AMOUNT);

        assertEq(terms.token, mockTerms.token);
        assertEq(terms.periodInSeconds, mockTerms.periodInSeconds);
        assertEq(terms.durationInPeriods, mockTerms.durationInPeriods);
        assertEq(terms.interestRateFactor, mockTerms.interestRateFactor);
        assertEq(terms.addonRecipient, mockTerms.addonRecipient);
        assertEq(terms.addonAmount, mockTerms.addonAmount);
        assertEq(terms.interestRatePrimary, mockTerms.interestRatePrimary);
        assertEq(terms.interestRateSecondary, mockTerms.interestRateSecondary);
        assertTrue(terms.interestFormula == Interest.Formula.Simple);
        assertEq(terms.autoRepayment, mockTerms.autoRepayment);
    }

    /************************************************
     *  Test `mockLoanTerms` function
     ***********************************************/

    function test_mockLoanTerms() public {
        terms = initTermsConfig();

        creditLineMock.mockLoanTerms(BORROWER, MOCK_AMOUNT, terms);
        Loan.Terms memory mockTerms = creditLineMock.determineLoanTerms(BORROWER, MOCK_AMOUNT);

        assertEq(terms.token, mockTerms.token);
        assertEq(terms.periodInSeconds, mockTerms.periodInSeconds);
        assertEq(terms.durationInPeriods, mockTerms.durationInPeriods);
        assertEq(terms.interestRateFactor, mockTerms.interestRateFactor);
        assertEq(terms.addonRecipient, mockTerms.addonRecipient);
        assertEq(terms.addonAmount, mockTerms.addonAmount);
        assertEq(terms.interestRatePrimary, mockTerms.interestRatePrimary);
        assertEq(terms.interestRateSecondary, mockTerms.interestRateSecondary);
        assertTrue(terms.interestFormula == Interest.Formula.Simple);
        assertEq(terms.autoRepayment, mockTerms.autoRepayment);
    }
}

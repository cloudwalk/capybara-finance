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
        Loan.Terms memory terms = mock.onBeforeLoanTaken(address(0x1), 100, 1);

        assertEq(terms.token, address(0x0));
        assertEq(terms.periodInSeconds, 0);
        assertEq(terms.durationInPeriods, 0);
        assertEq(terms.interestRateFactor, 0);
        assertEq(terms.interestRatePrimary, 0);
        assertEq(terms.interestRateSecondary, 0);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(terms.addonRecipient, address(0x0));
        assertEq(terms.autoRepayment, false);
        assertEq(terms.addonAmount, 0);

        mock.mockLoanTerms(
            address(0x1),
            100,
            Loan.Terms({
                token: address(0x1),
                holder: address(0x2),
                periodInSeconds: 100,
                durationInPeriods: 200,
                interestRateFactor: 300,
                interestRatePrimary: 400,
                interestRateSecondary: 500,
                interestFormula: Interest.Formula.Compound,
                addonRecipient: address(0x2),
                autoRepayment: true,
                addonAmount: 600
            })
        );

        terms = mock.onBeforeLoanTaken(address(0x1), 100, 1);

        assertEq(terms.token, address(0x1));
        assertEq(terms.periodInSeconds, 100);
        assertEq(terms.durationInPeriods, 200);
        assertEq(terms.interestRateFactor, 300);
        assertEq(terms.interestRatePrimary, 400);
        assertEq(terms.interestRateSecondary, 500);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Compound));
        assertEq(terms.addonRecipient, address(0x2));
        assertEq(terms.autoRepayment, true);
        assertEq(terms.addonAmount, 600);
    }

    function test_determineLoanTerms() public {
        Loan.Terms memory terms = mock.determineLoanTerms(address(0x1), 100);

        assertEq(terms.token, address(0x0));
        assertEq(terms.periodInSeconds, 0);
        assertEq(terms.durationInPeriods, 0);
        assertEq(terms.interestRateFactor, 0);
        assertEq(terms.interestRatePrimary, 0);
        assertEq(terms.interestRateSecondary, 0);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(terms.addonRecipient, address(0x0));
        assertEq(terms.autoRepayment, false);
        assertEq(terms.addonAmount, 0);

        mock.mockLoanTerms(
            address(0x1),
            100,
            Loan.Terms({
                token: address(0x1),
                holder: address(0x2),
                periodInSeconds: 100,
                durationInPeriods: 200,
                interestRateFactor: 300,
                interestRatePrimary: 400,
                interestRateSecondary: 500,
                interestFormula: Interest.Formula.Compound,
                addonRecipient: address(0x2),
                autoRepayment: true,
                addonAmount: 600
            })
        );

        terms = mock.determineLoanTerms(address(0x1), 100);

        assertEq(terms.token, address(0x1));
        assertEq(terms.periodInSeconds, 100);
        assertEq(terms.durationInPeriods, 200);
        assertEq(terms.interestRateFactor, 300);
        assertEq(terms.interestRatePrimary, 400);
        assertEq(terms.interestRateSecondary, 500);
        assertEq(terms.autoRepayment, true);
        assertEq(uint256(terms.interestFormula), uint256(Interest.Formula.Compound));
        assertEq(terms.addonRecipient, address(0x2));
        assertEq(terms.addonAmount, 600);
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
        assertEq(mock.token(), address(0x0));
        mock.mockTokenAddress(address(0x1));
        assertEq(mock.token(), address(0x1));
    }

    function test_kind() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.kind();
    }
}

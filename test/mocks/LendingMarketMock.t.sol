// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

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
        mock.takeLoan(address(0x1), 100);
    }

    function test_repayLoan() public {
        vm.prank(address(mock));
        vm.expectEmit(true, true, true, true, address(mock));
        emit RepayLoanCalled(100, 100);
        mock.repayLoan(100, 100);
    }

    function test_freeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.freeze(1);
    }

    function test_unfreeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.unfreeze(1);
    }

    function test_updateLoanDuration() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanDuration(1, 100);
    }

    function test_updateLoanMoratorium() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanMoratorium(1, 100);
    }

    function test_updateLoanInterestRatePrimary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanInterestRatePrimary(1, 100);
    }

    function test_updateLoanInterestRateSecondary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLoanInterestRateSecondary(1, 100);
    }

    function test_registerCreditLine() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit RegisterCreditLineCalled(address(0x1), address(0x2));
        mock.registerCreditLine(address(0x1), address(0x2));
    }

    function test_registerLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(mock));
        emit RegisterLiquidityPoolCalled(address(0x3), address(0x4));
        mock.registerLiquidityPool(address(0x3), address(0x4));
    }

    function test_getCreditLineLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getCreditLineLender(address(0x1));
    }

    function test_getLiquidityPoolLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLiquidityPoolLender(address(0x1));
    }

    function test_getLoanState() public {
        Loan.State memory loan = mock.getLoanState(1);

        assertEq(loan.token, address(0x0));
        assertEq(loan.borrower, address(0x0));
        assertEq(loan.periodInSeconds, 0);
        assertEq(loan.durationInPeriods, 0);
        assertEq(loan.interestRateFactor, 0);
        assertEq(loan.interestRatePrimary, 0);
        assertEq(loan.interestRateSecondary, 0);
        assertEq(uint256(loan.interestFormula), uint256(Interest.Formula.Simple));
        assertEq(loan.initialBorrowAmount, 0);
        assertEq(loan.trackedBorrowAmount, 0);
        assertEq(loan.startDate, 0);
        assertEq(loan.trackedDate, 0);
        assertEq(loan.freezeDate, 0);

        mock.mockLoanState(
            1,
            Loan.State({
                token: address(0x1),
                borrower: address(0x2),
                holder: address(0x3),
                periodInSeconds: 100,
                durationInPeriods: 200,
                interestRateFactor: 300,
                interestRatePrimary: 400,
                interestRateSecondary: 500,
                interestFormula: Interest.Formula.Compound,
                initialBorrowAmount: 600,
                trackedBorrowAmount: 700,
                startDate: 800,
                trackedDate: 900,
                freezeDate: 1000,
                autoRepayment: false
            })
        );

        loan = mock.getLoanState(1);

        assertEq(loan.token, address(0x1));
        assertEq(loan.borrower, address(0x2));
        assertEq(loan.periodInSeconds, 100);
        assertEq(loan.durationInPeriods, 200);
        assertEq(loan.interestRateFactor, 300);
        assertEq(loan.interestRatePrimary, 400);
        assertEq(loan.interestRateSecondary, 500);
        assertEq(uint256(loan.interestFormula), uint256(Interest.Formula.Compound));
        assertEq(loan.initialBorrowAmount, 600);
        assertEq(loan.trackedBorrowAmount, 700);
        assertEq(loan.startDate, 800);
        assertEq(loan.trackedDate, 900);
        assertEq(loan.freezeDate, 1000);
    }

    function test_getLoanPreview() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLoanPreview(1, 0);
    }

    function test_registry() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.registry();
    }
}

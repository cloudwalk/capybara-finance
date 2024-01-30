// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LendingMarketMock} from "src/mocks/LendingMarketMock.sol";

/// @title LendingMarketMockTest contract
/// @notice Contains tests for the LendingMarketMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketMockTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);

    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);

    /************************************************
     *  Storage variables
     ***********************************************/

    LendingMarketMock public mock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        mock = new LendingMarketMock();
    }

    /************************************************
     *  ILendingMarket functions
     ***********************************************/

    function test_takeLoan() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.takeLoan(address(0x1), 100);
    }

    function test_repayLoan() public {
        vm.expectRevert(Error.NotImplemented.selector);
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

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.updateLender(address(0x1), address(0x2));
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

    function test_getLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLender(address(0x1));
    }

    function test_getLiquidityPool() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLiquidityPool(address(0x1));
    }

    function test_getLoan() public {
        Loan.State memory loan = mock.getLoan(1);

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
        assertEq(loan.trackDate, 0);
        assertEq(loan.freezeDate, 0);

        mock.mockLoanState(
            1,
            Loan.State({
                token: address(0x1),
                borrower: address(0x2),
                periodInSeconds: 100,
                durationInPeriods: 200,
                interestRateFactor: 300,
                interestRatePrimary: 400,
                interestRateSecondary: 500,
                interestFormula: Interest.Formula.Compound,
                initialBorrowAmount: 600,
                trackedBorrowAmount: 700,
                startDate: 800,
                trackDate: 900,
                freezeDate: 1000
            })
        );

        loan = mock.getLoan(1);

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
        assertEq(loan.trackDate, 900);
        assertEq(loan.freezeDate, 1000);
    }

    function test_getLoanBalance() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.getLoanBalance(1, 0);
    }

    function test_registry() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.registry();
    }
}

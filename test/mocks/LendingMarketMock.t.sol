// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {LendingMarketMock} from "src/mocks/LendingMarketMock.sol";
import {Loan} from "src/libraries/Loan.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Error} from "src/libraries/Error.sol";

/// @title LendingMarketMockTest contract
/// @notice Contains tests for the CreditLineFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketMockTest is Test {

    /************************************************
     *  Events
     ***********************************************/
    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);
    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);
    event RepayLoanCalled(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );

    /************************************************
     *  State variables and constants
     ***********************************************/
    Loan.State state;

    address public constant TOKEN = address(bytes20(keccak256("TOKEN")));
    address public constant OWNER = address(bytes20(keccak256("OWNER")));
    address public constant BORROWER = address(bytes20(keccak256("BORROWER")));
    address public constant LIQUIDITY_POOL = address(bytes20(keccak256("LIQUIDITY_POOL")));
    address public constant LENDER = address(bytes20(keccak256("LENDER")));
    address public constant CREDIT_LINE = address(bytes20(keccak256("CREDIT_LINE")));
    uint256 public constant LOAN_ID = 1;
    uint256 public constant AMOUNT = 1000;
    uint256 public constant ZERO_VALUE = 0;
    uint256 public constant NEW_VALUE = 100;
    uint256 public constant BASE_BLOCKTIMESTAMP = 1641070800;
    
    uint32 public constant INIT_STATE_PERIOD_IN_SECONDS = 600;
    uint32 public constant INIT_STATE_DURATION_IN_PERIODS = 50;
    uint32 public constant INIT_STATE_INTEREST_RATE_FACTOR = 1000;
    address public constant INIT_STATE_ADDON_RECIPIENT = address(bytes20(keccak256("RECIPIENT")));
    uint64 public constant INIT_STATE_ADDON_AMOUNT = 1000;
    uint32 public constant INIT_STATE_INTEREST_RATE_PRIMARY = 7;
    uint32 public constant INIT_STATE_INTEREST_RATE_SECONDARY = 9;
    bool public constant INIT_STATE_AUTOREPAYMENT = true;

    LendingMarketMock public lendingMarketMock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        lendingMarketMock = new LendingMarketMock();

        vm.stopPrank();
    }

    function initStateConfig()
        public
        pure
        returns (Loan.State memory)
    {
        return Loan.State({
            token: TOKEN,
            interestRatePrimary: uint32(INIT_STATE_INTEREST_RATE_PRIMARY),
            interestRateSecondary: uint32(INIT_STATE_INTEREST_RATE_SECONDARY),
            interestRateFactor: uint32(INIT_STATE_INTEREST_RATE_FACTOR),
            borrower: BORROWER,
            startDate: uint32(BASE_BLOCKTIMESTAMP),
            initialBorrowAmount: uint64(AMOUNT),
            periodInSeconds: uint32(INIT_STATE_PERIOD_IN_SECONDS),
            durationInPeriods: uint32(INIT_STATE_DURATION_IN_PERIODS),
            trackedBorrowAmount: uint64(AMOUNT),
            trackDate: uint32(BASE_BLOCKTIMESTAMP),
            freezeDate: uint32(BASE_BLOCKTIMESTAMP),
            autoRepayment: INIT_STATE_AUTOREPAYMENT,
            interestFormula: Interest.Formula.Simple
        });
    }

    /************************************************
     *  Test `takeLoan` function
     ***********************************************/

    function test_takeLoan() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.takeLoan(CREDIT_LINE, AMOUNT);
    }

    /************************************************
     *  Test `repayLoan` function
     ***********************************************/

    function test_repayLoan() public {
        vm.expectEmit(true, true, true, true, address(lendingMarketMock));
        emit RepayLoanCalled(LOAN_ID, LIQUIDITY_POOL, address(0), AMOUNT, ZERO_VALUE);
        vm.prank(LIQUIDITY_POOL);
        lendingMarketMock.repayLoan(LOAN_ID, AMOUNT);
    }

    /************************************************
     *  Test `freeze` function
     ***********************************************/

    function test_freeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.freeze(LOAN_ID);
    }

    /************************************************
     *  Test `unfreeze` function
     ***********************************************/

    function test_unfreeze() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.unfreeze(LOAN_ID);
    }

    /************************************************
     *  Test `updateLoanDuration` function
     ***********************************************/

    function test_updateLoanDuration() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.updateLoanDuration(LOAN_ID, NEW_VALUE);
    }

    /************************************************
     *  Test `updateLoanMoratorium` function
     ***********************************************/

    function test_updateLoanMoratorium() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.updateLoanDuration(LOAN_ID, NEW_VALUE);
    }

    /************************************************
     *  Test `updateLoanInterestRatePrimary` function
     ***********************************************/

    function test_updateLoanInterestRatePrimary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.updateLoanInterestRatePrimary(LOAN_ID, NEW_VALUE);
    }

    /************************************************
     *  Test `updateLoanInterestRateSecondary` function
     ***********************************************/

    function test_updateLoanInterestRateSecondary() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.updateLoanInterestRateSecondary(LOAN_ID, NEW_VALUE);
    }

    /************************************************
     *  Test `updateLender` function
     ***********************************************/

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.updateLender(CREDIT_LINE, LENDER);
    }

    /************************************************
     *  Test `registerCreditLine` function
     ***********************************************/

    function test_registerCreditLine() public {
        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(lendingMarketMock));
        emit RegisterCreditLineCalled(LENDER, CREDIT_LINE);

        lendingMarketMock.registerCreditLine(LENDER, CREDIT_LINE);

    }

    /************************************************
     *  Test `registerLiquidityPool` function
     ***********************************************/

    function test_registerLiquidityPool() public {
        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(lendingMarketMock));
        emit RegisterLiquidityPoolCalled(LENDER, LIQUIDITY_POOL);

        lendingMarketMock.registerLiquidityPool(LENDER, LIQUIDITY_POOL);
    }

    /************************************************
     *  Test `getLender` function
     ***********************************************/

    function test_getLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.getLender(CREDIT_LINE);
    }

    /************************************************
     *  Test `getLiquidityPool` function
     ***********************************************/

    function test_getLiquidityPool() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.getLiquidityPool(LENDER);
    }

    /************************************************
     *  Test `getLoanPreview` function
     ***********************************************/

    function test_getLoanPreview() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.getLoanPreview(LOAN_ID, AMOUNT, BASE_BLOCKTIMESTAMP);
    }

    /************************************************
     *  Test `getOutstandingBalance` function
     ***********************************************/

    function test_getOutstandingBalance() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.getOutstandingBalance(LOAN_ID);
    }

    /************************************************
     *  Test `getCurrentPeriodDate` function
     ***********************************************/

    function test_getCurrentPeriodDate() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.getCurrentPeriodDate(LOAN_ID);
    }

    /************************************************
     *  Test `registry` function
     ***********************************************/

    function test_registry() public {
        vm.expectRevert(Error.NotImplemented.selector);
        lendingMarketMock.registry();
    }

    /************************************************
     *  Test `mockLoanState/getLoan` function
    ***********************************************/

    function test_mockLoanState_onTakeLoan() public {
        state = initStateConfig();

        lendingMarketMock.mockLoanState(LOAN_ID, state);
        Loan.State memory mockState = lendingMarketMock.getLoan(LOAN_ID);

        assertEq(state.token, mockState.token);
        assertEq(state.interestRatePrimary, mockState.interestRatePrimary);
        assertEq(state.interestRateSecondary, mockState.interestRateSecondary);
        assertEq(state.interestRateFactor, mockState.interestRateFactor);
        assertEq(state.borrower, mockState.borrower);
        assertEq(state.startDate, mockState.startDate);
        assertEq(state.initialBorrowAmount, mockState.initialBorrowAmount);
        assertEq(state.periodInSeconds, mockState.periodInSeconds);
        assertEq(state.durationInPeriods, mockState.durationInPeriods);
        assertEq(state.trackedBorrowAmount, mockState.trackedBorrowAmount);
        assertEq(state.trackDate, mockState.trackDate);
        assertEq(state.freezeDate, mockState.freezeDate);
        assertTrue(state.interestFormula == Interest.Formula.Simple);
        assertEq(state.autoRepayment, mockState.autoRepayment);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LendingMarketMock} from "src/mocks/LendingMarketMock.sol";
import {CreditLineMock} from "src/mocks/CreditLineMock.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";

/// @title LiquidityPoolAccountableTest contract
/// @notice Contains tests for the LiquidityPoolAccountable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolAccountableTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event Deposit(address indexed creditLine, uint256 amount);
    event Withdraw(address indexed tokenSource, uint256 amount);

    /************************************************
     *  Storage variables
     ***********************************************/

    LiquidityPoolAccountable public liquidityPool;
    LendingMarketMock public lendingMarket;
    CreditLineMock public creditLine;
    ERC20Mock public token;

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant NONEXISTENT_TOKEN_SOUTRCE = address(bytes20(keccak256("unexisting_token_source")));

    uint256 public constant LOAN_ID = 1;
    uint256 public constant DEPOSIT_AMOUNT = 100;
    uint256 public constant NONEXISTENT_LOAN_ID = 999999999;
    uint16 public constant KIND = 1;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        token = new ERC20Mock(0);
        creditLine = new CreditLineMock();
        creditLine.mockTokenAddress(address(token));
        lendingMarket = new LendingMarketMock();
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
    }

    function configureLender() public {
        vm.startPrank(LENDER);
        token.mint(LENDER, DEPOSIT_AMOUNT);
        token.approve(address(liquidityPool), DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
        assertEq(liquidityPool.market(), address(lendingMarket));
        assertEq(liquidityPool.lender(), LENDER);
        assertEq(liquidityPool.owner(), LENDER);
    }

    function test_initializer_Revert_IfMarketIsZeroAddress() public {
        liquidityPool = new LiquidityPoolAccountable();
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.initialize(address(0), LENDER);
    }

    function test_initializer_Revert_IfLenderIsZeroAddress() public {
        liquidityPool = new LiquidityPoolAccountable();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        liquidityPool.initialize(address(lendingMarket), address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        liquidityPool.initialize(address(lendingMarket), LENDER);
    }

    /************************************************
     *  Test `pause` function
     ***********************************************/

    function test_pause() public {
        assertEq(liquidityPool.paused(), false);
        vm.prank(LENDER);
        liquidityPool.pause();
        assertEq(liquidityPool.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(LENDER);
        liquidityPool.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.pause();
    }

    /************************************************
     *  Test `unpause` function
     ***********************************************/

    function test_unpause() public {
        vm.startPrank(LENDER);
        assertEq(liquidityPool.paused(), false);
        liquidityPool.pause();
        assertEq(liquidityPool.paused(), true);
        liquidityPool.unpause();
        assertEq(liquidityPool.paused(), false);
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(liquidityPool.paused(), false);
        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        liquidityPool.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(LENDER);
        liquidityPool.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.unpause();
    }

    /************************************************
     *  Test `deposit` function
     ***********************************************/

    function test_deposit() public {
        configureLender();

        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), 0);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Deposit(address(creditLine), DEPOSIT_AMOUNT);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), type(uint256).max);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);
    }

    function test_deposit_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.deposit(address(0), DEPOSIT_AMOUNT);
    }

    function test_deposit_Revert_IfDepositAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.deposit(address(creditLine), 0);
    }

    function test_deposit_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);
    }

    /************************************************
     *  Test `withdraw` function
     ***********************************************/

    function test_withdraw_CreditLineBalance() public {
        configureLender();

        vm.startPrank(LENDER);

        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdraw(address(creditLine), DEPOSIT_AMOUNT - 1);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT - 1);

        assertEq(token.balanceOf(LENDER), DEPOSIT_AMOUNT - 1);
        assertEq(token.balanceOf(address(liquidityPool)), 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), 1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 1);
    }

    function test_withdraw_TokenBalance() public {
        configureLender();

        vm.startPrank(LENDER);

        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdraw(address(token), DEPOSIT_AMOUNT - 1);
        liquidityPool.withdraw(address(token), DEPOSIT_AMOUNT - 1);

        assertEq(token.balanceOf(LENDER), DEPOSIT_AMOUNT - 1);
        assertEq(token.balanceOf(address(liquidityPool)), 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), 1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);
    }

    function test_withdraw_Revert_ZeroBalance() public {
        vm.prank(LENDER);
        vm.expectRevert(LiquidityPoolAccountable.ZeroBalance.selector);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT);
    }

    function test_withdraw_Revert_CreditLineBalance_InsufficientBalance() public {
        configureLender();
        vm.startPrank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT + 1);
    }

    function test_withdraw_Revert_TokenBalance_InsufficientBalance() public {
        configureLender();
        vm.startPrank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(address(token), DEPOSIT_AMOUNT + 1);
    }

    function test_withdraw_Revert_IfTokenSourceIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.withdraw(address(0), DEPOSIT_AMOUNT);
    }

    function test_withdraw_Revert_IfWithdrawAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.withdraw(address(creditLine), 0);
    }

    function test_withdraw_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT);
    }

    /************************************************
     *  Test `onBeforeTakeLoan` function
     ***********************************************/

    function test_onBeforeTakeLoan() public {
        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeTakeLoan(LOAN_ID, address(creditLine)), true);
    }

    function test_onBeforeTakeLoan_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onBeforeTakeLoan(LOAN_ID, address(creditLine));
    }

    function test_onBeforeTakeLoan_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onBeforeTakeLoan(LOAN_ID, address(creditLine));
    }

    /************************************************
     *  Test `onAfterTakeLoan` function
     ***********************************************/

    function test_onAfterTakeLoan() public {
        configureLender();
        lendingMarket.mockLoanState(
            LOAN_ID,
            Loan.State({
                token: address(token),
                borrower: address(0),
                periodInSeconds: 0,
                durationInPeriods: 0,
                interestRateFactor: 0,
                interestRatePrimary: 0,
                interestRateSecondary: 0,
                interestFormula: Interest.Formula.Simple,
                startDate: 0,
                freezeDate: 0,
                trackDate: 0,
                initialBorrowAmount: DEPOSIT_AMOUNT - 1,
                trackedBorrowAmount: 0
            })
        );

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(liquidityPool.getCreditLine(LOAN_ID), address(0));
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterTakeLoan(LOAN_ID, address(creditLine)), true);

        assertEq(liquidityPool.getCreditLine(LOAN_ID), address(creditLine));
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 1);
    }

    function test_onAfterTakeLoan_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onAfterTakeLoan(LOAN_ID, address(creditLine));
    }

    function test_onAfterTakeLoan_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onAfterTakeLoan(LOAN_ID, address(creditLine));
    }

    /************************************************
     *  Test `onBeforeLoanPayment` function
     ***********************************************/

    function test_onBeforeLoanPayment() public {
        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeLoanPayment(LOAN_ID, DEPOSIT_AMOUNT), true);
    }

    function test_onBeforeLoanPayment_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onBeforeLoanPayment(LOAN_ID, DEPOSIT_AMOUNT);
    }

    function test_onBeforeLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onBeforeLoanPayment(LOAN_ID, DEPOSIT_AMOUNT);
    }

    /************************************************
     *  Test `onAfterLoanPayment` function
     ***********************************************/

    function test_onAfterLoanPayment_CreditLineBalance() public {
        configureLender();
        lendingMarket.mockLoanState(
            LOAN_ID,
            Loan.State({
                token: address(token),
                borrower: address(0),
                periodInSeconds: 0,
                durationInPeriods: 0,
                interestRateFactor: 0,
                interestRatePrimary: 0,
                interestRateSecondary: 0,
                interestFormula: Interest.Formula.Simple,
                startDate: 0,
                freezeDate: 0,
                trackDate: 0,
                initialBorrowAmount: DEPOSIT_AMOUNT,
                trackedBorrowAmount: 0
            })
        );

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);

        vm.startPrank(address(lendingMarket));
        assertEq(liquidityPool.onAfterTakeLoan(LOAN_ID, address(creditLine)), true);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);
        assertEq(liquidityPool.onAfterLoanPayment(LOAN_ID, DEPOSIT_AMOUNT), true);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment_NonCreditLineBalance() public {
        configureLender();
        lendingMarket.mockLoanState(
            LOAN_ID,
            Loan.State({
                token: address(token),
                borrower: address(0),
                periodInSeconds: 0,
                durationInPeriods: 0,
                interestRateFactor: 0,
                interestRatePrimary: 0,
                interestRateSecondary: 0,
                interestFormula: Interest.Formula.Simple,
                startDate: 0,
                freezeDate: 0,
                trackDate: 0,
                initialBorrowAmount: DEPOSIT_AMOUNT,
                trackedBorrowAmount: 0
            })
        );

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanPayment(NONEXISTENT_LOAN_ID, DEPOSIT_AMOUNT), true);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onAfterLoanPayment(LOAN_ID, DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onAfterLoanPayment(LOAN_ID, DEPOSIT_AMOUNT);
    }

    /************************************************
     *  Test `getTokenBalance` function
     ***********************************************/

    function test_getTokenBalance() public {
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);
        assertEq(liquidityPool.getTokenBalance(address(token)), 0);
        assertEq(liquidityPool.getTokenBalance(NONEXISTENT_TOKEN_SOUTRCE), 0);

        vm.startPrank(LENDER);
        token.mint(LENDER, DEPOSIT_AMOUNT + 1);
        token.approve(address(liquidityPool), DEPOSIT_AMOUNT + 1);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT + 1);
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT + 2);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT + 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT * 2 + 3);
        assertEq(liquidityPool.getTokenBalance(NONEXISTENT_TOKEN_SOUTRCE), 0);
    }

    /************************************************
     *  Test `getCreditLine` function
     ***********************************************/

    function test_getCreditLine() public {
        configureLender();
        lendingMarket.mockLoanState(
            LOAN_ID,
            Loan.State({
                token: address(token),
                borrower: address(0),
                periodInSeconds: 0,
                durationInPeriods: 0,
                interestRateFactor: 0,
                interestRatePrimary: 0,
                interestRateSecondary: 0,
                interestFormula: Interest.Formula.Simple,
                startDate: 0,
                freezeDate: 0,
                trackDate: 0,
                initialBorrowAmount: DEPOSIT_AMOUNT,
                trackedBorrowAmount: 0
            })
        );

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);

        assertEq(liquidityPool.getCreditLine(LOAN_ID), address(0));

        vm.prank(address(lendingMarket));
        liquidityPool.onAfterTakeLoan(LOAN_ID, address(creditLine));

        assertEq(liquidityPool.getCreditLine(LOAN_ID), address(creditLine));
    }

    /************************************************
     *  Test view functions
     ***********************************************/

    function test_lendingMarket() public {
        assertEq(liquidityPool.market(), address(lendingMarket));
    }

    function test_lender() public {
        assertEq(liquidityPool.lender(), LENDER);
    }

    function test_kind() public {
        assertEq(liquidityPool.kind(), KIND);
    }
}

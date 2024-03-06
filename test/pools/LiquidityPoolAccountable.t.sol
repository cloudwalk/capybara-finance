// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/libraries/Loan.sol";
import { Error } from "src/libraries/Error.sol";
import { Interest } from "src/libraries/Interest.sol";

import { ERC20Mock } from "src/mocks/ERC20Mock.sol";
import { CreditLineMock } from "src/mocks/CreditLineMock.sol";
import { LendingMarketMock } from "src/mocks/LendingMarketMock.sol";

import { LiquidityPoolAccountable } from "src/pools/LiquidityPoolAccountable.sol";

/// @title LiquidityPoolAccountableTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LiquidityPoolAccountable` contract.
contract LiquidityPoolAccountableTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event ConfigureAdmin(address indexed admin, bool adminStatus);
    event Deposit(address indexed creditLine, uint256 amount);
    event Withdraw(address indexed tokenSource, uint256 amount);
    event AutoRepay(uint256 numberOfLoans);
    event RepayLoanCalled(uint256 indexed loanId, uint256 repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    ERC20Mock public token;
    CreditLineMock public creditLine;
    LendingMarketMock public lendingMarket;
    LiquidityPoolAccountable public liquidityPool;

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant TOKEN_SOURCE_NONEXISTENT = address(bytes20(keccak256("token_source_nonexistent")));

    uint256 public constant LOAN_ID_1 = 1;
    uint256 public constant LOAN_ID_2 = 2;
    uint256 public constant LOAN_ID_3 = 3;
    uint256 public constant LOAN_ID_NONEXISTENT = 999_999_999;

    uint64 public constant DEPOSIT_AMOUNT_1 = 100;
    uint64 public constant DEPOSIT_AMOUNT_2 = 200;
    uint64 public constant DEPOSIT_AMOUNT_3 = 300;

    uint16 public constant KIND_1 = 1;
    uint8 public constant DECIMALS = 6;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        token = new ERC20Mock(0, DECIMALS);
        creditLine = new CreditLineMock();
        creditLine.mockTokenAddress(address(token));
        lendingMarket = new LendingMarketMock();
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);
    }

    function configureLender() public {
        vm.startPrank(LENDER);
        token.mint(LENDER, DEPOSIT_AMOUNT_1);
        token.approve(address(liquidityPool), DEPOSIT_AMOUNT_1);
        vm.stopPrank();
    }

    function getBatchLoanData() public pure returns (uint256[] memory, uint256[] memory) {
        uint256[] memory loanIds = new uint256[](3);
        loanIds[0] = LOAN_ID_1;
        loanIds[1] = LOAN_ID_2;
        loanIds[2] = LOAN_ID_3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = DEPOSIT_AMOUNT_1;
        amounts[1] = DEPOSIT_AMOUNT_2;
        amounts[2] = DEPOSIT_AMOUNT_3;

        return (loanIds, amounts);
    }

    function initLoanState() public returns (Loan.State memory) {
        return Loan.State({
            token: address(token),
            borrower: address(0),
            treasury: address(0),
            periodInSeconds: 0,
            durationInPeriods: 0,
            interestRateFactor: 0,
            interestRatePrimary: 0,
            interestRateSecondary: 0,
            interestFormula: Interest.Formula.Simple,
            startDate: 0,
            freezeDate: 0,
            trackedDate: 0,
            initialBorrowAmount: 0,
            trackedBorrowBalance: 0,
            autoRepayment: false
        });
    }

    // -------------------------------------------- //
    //  Test initializer                            //
    // -------------------------------------------- //

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

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

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

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

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

    // -------------------------------------------- //
    //  Test `configureAdmin` function              //
    // -------------------------------------------- //

    function test_configureAdmin() public {
        assertEq(liquidityPool.isAdmin(ADMIN), false);

        vm.startPrank(LENDER);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit ConfigureAdmin(ADMIN, true);
        liquidityPool.configureAdmin(ADMIN, true);

        assertEq(liquidityPool.isAdmin(ADMIN), true);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit ConfigureAdmin(ADMIN, false);
        liquidityPool.configureAdmin(ADMIN, false);

        assertEq(liquidityPool.isAdmin(ADMIN), false);
    }

    function test_configureAdmin_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.configureAdmin(ADMIN, true);
    }

    function test_configureAdmin_Revert_IfAdminIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.configureAdmin(address(0), true);
    }

    function test_configureAdmin_Revert_IfAdminIsAlreadyConfigured() public {
        vm.startPrank(LENDER);
        liquidityPool.configureAdmin(ADMIN, true);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        liquidityPool.configureAdmin(ADMIN, true);
    }

    // -------------------------------------------- //
    //  Test `deposit` function                     //
    // -------------------------------------------- //

    function test_deposit() public {
        configureLender();

        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), 0);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Deposit(address(creditLine), DEPOSIT_AMOUNT_1);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), type(uint256).max);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);
    }

    function test_deposit_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);
    }

    function test_deposit_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.deposit(address(0), DEPOSIT_AMOUNT_1);
    }

    function test_deposit_Revert_IfDepositAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.deposit(address(creditLine), 0);
    }

    // -------------------------------------------- //
    //  Test `withdraw` function                    //
    // -------------------------------------------- //

    function test_withdraw_CreditLineBalance() public {
        configureLender();

        vm.startPrank(LENDER);

        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT_1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdraw(address(creditLine), DEPOSIT_AMOUNT_1 - 1);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT_1 - 1);

        assertEq(token.balanceOf(LENDER), DEPOSIT_AMOUNT_1 - 1);
        assertEq(token.balanceOf(address(liquidityPool)), 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), 1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 1);
    }

    function test_withdraw_TokenBalance() public {
        configureLender();

        vm.startPrank(LENDER);

        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT_1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdraw(address(token), DEPOSIT_AMOUNT_1 - 1);
        liquidityPool.withdraw(address(token), DEPOSIT_AMOUNT_1 - 1);

        assertEq(token.balanceOf(LENDER), DEPOSIT_AMOUNT_1 - 1);
        assertEq(token.balanceOf(address(liquidityPool)), 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), 1);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);
    }

    function test_withdraw_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT_1);
    }

    function test_withdraw_Revert_IfTokenSourceIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.withdraw(address(0), DEPOSIT_AMOUNT_1);
    }

    function test_withdraw_Revert_IfWithdrawAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.withdraw(address(creditLine), 0);
    }

    function test_withdraw_Revert_CreditLineBalance_InsufficientBalance() public {
        configureLender();
        vm.startPrank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT_1 + 1);
    }

    function test_withdraw_Revert_TokenBalance_InsufficientBalance() public {
        configureLender();
        vm.startPrank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(address(token), DEPOSIT_AMOUNT_1 + 1);
    }

    function test_withdraw_Revert_ZeroBalance() public {
        vm.prank(LENDER);
        vm.expectRevert(LiquidityPoolAccountable.ZeroBalance.selector);
        liquidityPool.withdraw(address(creditLine), DEPOSIT_AMOUNT_1);
    }

    // -------------------------------------------- //
    //  Test `autoRepay` function                   //
    // -------------------------------------------- //

    function test_autoRepay() public {
        vm.prank(LENDER);
        liquidityPool.configureAdmin(ADMIN, true);
        (uint256[] memory loanIds, uint256[] memory amounts) = getBatchLoanData();

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit AutoRepay(loanIds.length);

        for (uint256 i = 0; i < loanIds.length; i++) {
            vm.expectEmit(true, true, true, true, address(lendingMarket));
            emit RepayLoanCalled(loanIds[i], amounts[i]);
        }

        vm.prank(ADMIN);
        liquidityPool.autoRepay(loanIds, amounts);
    }

    function test_deposit_Revert_IfCallerNotAdmin() public {
        (uint256[] memory loanIds, uint256[] memory amounts) = getBatchLoanData();

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.autoRepay(loanIds, amounts);
    }

    function test_autoRepay_Revert_IfArrayLengthMismatch() public {
        vm.prank(LENDER);
        liquidityPool.configureAdmin(ADMIN, true);

        (uint256[] memory loanIds, uint256[] memory amounts) = getBatchLoanData();
        uint256[] memory amountsIncorrectLength = new uint256[](2);
        amountsIncorrectLength[0] = amounts[0];
        amountsIncorrectLength[1] = amounts[1];

        vm.prank(ADMIN);
        vm.expectRevert(Error.ArrayLengthMismatch.selector);
        liquidityPool.autoRepay(loanIds, amountsIncorrectLength);
    }

    // -------------------------------------------- //
    //  Test `onBeforeLoanTaken` function           //
    // -------------------------------------------- //

    function test_onBeforeLoanTaken() public {
        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeLoanTaken(LOAN_ID_1, address(creditLine)), true);
    }

    function test_onBeforeLoanTaken_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1, address(creditLine));
    }

    function test_onBeforeLoanTaken_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1, address(creditLine));
    }

    // -------------------------------------------- //
    //  Test `onAfterLoanTaken` function            //
    // -------------------------------------------- //

    function test_onAfterLoanTaken() public {
        configureLender();
        Loan.State memory loan = initLoanState();
        loan.initialBorrowAmount = DEPOSIT_AMOUNT_1;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(liquidityPool.getCreditLine(LOAN_ID_1), address(0));
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanTaken(LOAN_ID_1, address(creditLine)), true);

        assertEq(liquidityPool.getCreditLine(LOAN_ID_1), address(creditLine));
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);
    }

    function test_onAfterLoanTaken_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onAfterLoanTaken(LOAN_ID_1, address(creditLine));
    }

    function test_onAfterLoanTaken_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onAfterLoanTaken(LOAN_ID_1, address(creditLine));
    }

    // -------------------------------------------- //
    //  Test `onBeforeLoanPayment` function         //
    // -------------------------------------------- //

    function test_onBeforeLoanPayment() public {
        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1), true);
    }

    function test_onBeforeLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onBeforeLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1);
    }

    function test_onBeforeLoanPayment_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onBeforeLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1);
    }

    // -------------------------------------------- //
    //  Test `onAfterLoanPayment` function          //
    // -------------------------------------------- //

    function test_onAfterLoanPayment_CreditLineBalance() public {
        configureLender();
        Loan.State memory loan = initLoanState();
        loan.initialBorrowAmount = DEPOSIT_AMOUNT_1;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);

        vm.startPrank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanTaken(LOAN_ID_1, address(creditLine)), true);
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);
        assertEq(liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1), true);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);
    }

    function test_onAfterLoanPayment_NonCreditLineBalance() public {
        configureLender();
        Loan.State memory loan = initLoanState();
        loan.initialBorrowAmount = DEPOSIT_AMOUNT_1;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanPayment(LOAN_ID_NONEXISTENT, DEPOSIT_AMOUNT_1), true);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1);
    }

    function test_onAfterLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1);
    }

    function test_onAfterLoanPayment_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getTokenBalance() public {
        assertEq(liquidityPool.getTokenBalance(address(creditLine)), 0);
        assertEq(liquidityPool.getTokenBalance(address(token)), 0);
        assertEq(liquidityPool.getTokenBalance(TOKEN_SOURCE_NONEXISTENT), 0);

        vm.startPrank(LENDER);
        token.mint(LENDER, DEPOSIT_AMOUNT_1 + 1);
        token.approve(address(liquidityPool), DEPOSIT_AMOUNT_1 + 1);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1 + 1);
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT_1 + 2);

        assertEq(liquidityPool.getTokenBalance(address(creditLine)), DEPOSIT_AMOUNT_1 + 1);
        assertEq(liquidityPool.getTokenBalance(address(token)), DEPOSIT_AMOUNT_1 * 2 + 3);
        assertEq(liquidityPool.getTokenBalance(TOKEN_SOURCE_NONEXISTENT), 0);
    }

    function test_getCreditLine() public {
        configureLender();
        Loan.State memory loan = initLoanState();
        loan.initialBorrowAmount = DEPOSIT_AMOUNT_1;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT_1);

        assertEq(liquidityPool.getCreditLine(LOAN_ID_1), address(0));

        vm.prank(address(lendingMarket));
        liquidityPool.onAfterLoanTaken(LOAN_ID_1, address(creditLine));

        assertEq(liquidityPool.getCreditLine(LOAN_ID_1), address(creditLine));
    }

    function test_isAdmin() public {
        assertFalse(liquidityPool.isAdmin(ADMIN));

        vm.prank(LENDER);
        liquidityPool.configureAdmin(ADMIN, true);

        assertTrue(liquidityPool.isAdmin(ADMIN));

        vm.prank(LENDER);
        liquidityPool.configureAdmin(ADMIN, false);

        assertFalse(liquidityPool.isAdmin(ADMIN));
    }

    function test_market() public {
        assertEq(liquidityPool.market(), address(lendingMarket));
    }

    function test_lender() public {
        assertEq(liquidityPool.lender(), LENDER);
    }

    function test_kind() public {
        assertEq(liquidityPool.kind(), KIND_1);
    }
}

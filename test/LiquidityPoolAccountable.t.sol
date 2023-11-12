// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";


import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LendingMarketMock} from "./mocks/LendingMarketMock.sol";
import {CreditLineMock} from "./mocks/CreditLineMock.sol";
import {ERC20Mintable} from "./mocks/ERC20Mintable.sol";

contract LiquidityPoolAccountableTest is Test {

    /************************************************
     *  Events
     ***********************************************/

    event Deposit(address indexed creditLine, uint256 amount);
    event Withdraw(address indexed tokenSource, uint256 amount);

    /************************************************
     *  Variables
     ***********************************************/

    ERC20Mintable public token;
    LiquidityPoolAccountable public pool;
    LendingMarketMock public market;
    CreditLineMock public line;

    /************************************************
     *  Constants
     ***********************************************/

    address public constant LINE = address(bytes20(keccak256("line")));
    address public MARKET = address(bytes20(keccak256("market")));

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));

    uint16 public constant KIND = 1;
    uint256 public constant LOAN_ID = 1;
    uint256 public constant TOKEN_AMOUNT = 100;

    address public constant NONEXISTENT_TOKEN_SOUTRCE = address(bytes20(keccak256("unexisting_token_source")));
    uint256 public constant NONEXISTENT_LOAN_ID = 999999999;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        token = new ERC20Mintable(0);

        line = new CreditLineMock();
        line.mockToken(address(token));

        market = new LendingMarketMock();
        pool = new LiquidityPoolAccountable(address(market), LENDER);

        MARKET = address(market);

        vm.prank(LENDER);
        token.approve(address(pool), type(uint256).max);
    }

    /************************************************
     *  Test constructor
     ***********************************************/

    function test_constructor() public {
        pool = new LiquidityPoolAccountable(MARKET, LENDER);
        assertEq(pool.market(), MARKET);
        assertEq(pool.lender(), LENDER);
        assertEq(pool.owner(), LENDER);
    }

    function test_constructor_Revert_IfMarketIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        pool = new LiquidityPoolAccountable(address(0), LENDER);
    }

    function test_constructor_Revert_IfLenderIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        pool = new LiquidityPoolAccountable(MARKET, address(0));
    }

    /************************************************
     *  Test `pause` function
     ***********************************************/

    function test_pause() public {
        assertEq(pool.paused(), false);
        vm.prank(LENDER);
        pool.pause();
        assertEq(pool.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(LENDER);
        pool.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        pool.pause();
    }

    /************************************************
     *  Test `unpause` function
     ***********************************************/

    function test_unpause() public {
        vm.startPrank(LENDER);
        assertEq(pool.paused(), false);
        pool.pause();
        assertEq(pool.paused(), true);
        pool.unpause();
        assertEq(pool.paused(), false);
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(pool.paused(), false);
        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        pool.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(LENDER);
        pool.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        pool.unpause();
    }

    /************************************************
     *  Test `deposit` function
     ***********************************************/

    function test_deposit() public {
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.allowance(address(pool), address(market)), 0);
        assertEq(pool.getTokenBalance(address(line)), 0);

        vm.startPrank(LENDER);

        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);

        vm.expectEmit(true, true, true, true, address(pool));
        emit Deposit(address(line), TOKEN_AMOUNT);
        pool.deposit(address(line), TOKEN_AMOUNT);

        assertEq(token.balanceOf(address(pool)), TOKEN_AMOUNT);
        assertEq(token.allowance(address(pool), address(market)), type(uint256).max);
        assertEq(pool.getTokenBalance(address(line)), TOKEN_AMOUNT);
    }

    function test_deposit_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAddress.selector);
        pool.deposit(address(0), TOKEN_AMOUNT);
    }

    function test_deposit_Revert_IfDepositAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        pool.deposit(LINE, 0);
    }

    function test_deposit_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        pool.deposit(LINE, TOKEN_AMOUNT);
    }

    /************************************************
     *  Test `withdraw` function
     ***********************************************/

    function test_withdraw_CreditLineBalance() public {
        vm.startPrank(LENDER);

        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);
        pool.deposit(address(line), TOKEN_AMOUNT);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(pool)), TOKEN_AMOUNT);
        assertEq(pool.getTokenBalance(address(token)), TOKEN_AMOUNT);
        assertEq(pool.getTokenBalance(address(line)), TOKEN_AMOUNT);

        vm.expectEmit(true, true, true, true, address(pool));
        emit Withdraw(address(line), TOKEN_AMOUNT - 1);
        pool.withdraw(address(line), TOKEN_AMOUNT - 1);

        assertEq(token.balanceOf(LENDER), TOKEN_AMOUNT - 1);
        assertEq(token.balanceOf(address(pool)), 1);
        assertEq(pool.getTokenBalance(address(token)), 1);
        assertEq(pool.getTokenBalance(address(line)), 1);
    }

    function test_withdraw_TokenBalance() public {
        vm.startPrank(LENDER);

        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);
        pool.deposit(address(line), TOKEN_AMOUNT);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(pool)), TOKEN_AMOUNT);
        assertEq(pool.getTokenBalance(address(token)), TOKEN_AMOUNT);
        assertEq(pool.getTokenBalance(address(line)), TOKEN_AMOUNT);

        vm.expectEmit(true, true, true, true, address(pool));
        emit Withdraw(address(token), TOKEN_AMOUNT - 1);
        pool.withdraw(address(token), TOKEN_AMOUNT - 1);

        assertEq(token.balanceOf(LENDER), TOKEN_AMOUNT - 1);
        assertEq(token.balanceOf(address(pool)), 1);
        assertEq(pool.getTokenBalance(address(token)), 1);
        assertEq(pool.getTokenBalance(address(line)), TOKEN_AMOUNT);
    }

    function test_withdraw_Revert_ZeroBalance() public {
        vm.prank(LENDER);
        vm.expectRevert(LiquidityPoolAccountable.ZeroBalance.selector);
        pool.withdraw(address(line), TOKEN_AMOUNT);
    }

    function test_withdraw_Revert_CreditLineBalance_InsufficientBalance() public {
        vm.startPrank(LENDER);

        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);
        pool.deposit(address(line), TOKEN_AMOUNT);

        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        pool.withdraw(address(line), TOKEN_AMOUNT + 1);
    }

    function test_withdraw_Revert_TokenBalance_InsufficientBalance() public {
        vm.startPrank(LENDER);

        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);
        pool.deposit(address(line), TOKEN_AMOUNT);

        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        pool.withdraw(address(token), TOKEN_AMOUNT + 1);
    }

    function test_withdraw_Revert_IfTokenSourceIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAddress.selector);
        pool.withdraw(address(0), TOKEN_AMOUNT);
    }

    function test_withdraw_Revert_IfWithdrawAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        pool.withdraw(LINE, 0);
    }

    function test_withdraw_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        pool.withdraw(LINE, TOKEN_AMOUNT);
    }

    /************************************************
     *  Test `onBeforeLoanTaken` function
     ***********************************************/

    function test_onBeforeLoanTaken() public {
        vm.prank(MARKET);
        assertEq(pool.onBeforeLoanTaken(LOAN_ID, address(line)), true);
    }

    function test_onBeforeLoanTaken_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onBeforeLoanTaken(LOAN_ID, address(line));
    }

    function test_onBeforeLoanTaken_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        pool.pause();

        vm.prank(MARKET);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onBeforeLoanTaken(LOAN_ID, address(line));
    }

    /************************************************
     *  Test `onAfterLoanTaken` function
     ***********************************************/

    function test_onAfterLoanTaken() public {
        token.mint(LENDER, TOKEN_AMOUNT);
        token.approve(address(pool), TOKEN_AMOUNT);

        vm.prank(LENDER);
        pool.deposit(address(line), TOKEN_AMOUNT);

        market.mockLoanState(LOAN_ID, Loan.State({
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
            initialBorrowAmount: TOKEN_AMOUNT - 1,
            trackedBorrowAmount: 0
        }));

        assertEq(pool.getCreditLine(LOAN_ID), address(0));
        assertEq(pool.getTokenBalance(address(line)), TOKEN_AMOUNT);

        vm.prank(address(market));
        assertEq(pool.onAfterLoanTaken(LOAN_ID, address(line)), true);

        assertEq(pool.getCreditLine(LOAN_ID), address(line));
        assertEq(pool.getTokenBalance(address(line)), 1);
    }

    function test_onAfterLoanTaken_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onAfterLoanTaken(LOAN_ID, LINE);
    }

    function test_onAfterLoanTaken_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        pool.pause();

        vm.prank(MARKET);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onAfterLoanTaken(LOAN_ID, LINE);
    }

    /************************************************
     *  Test `onBeforeLoanPayment` function
     ***********************************************/

    function test_onBeforeLoanPayment() public {
        vm.prank(MARKET);
        assertEq(pool.onBeforeLoanPayment(LOAN_ID, TOKEN_AMOUNT), true);
    }

    function test_onBeforeLoanPayment_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onBeforeLoanPayment(LOAN_ID, TOKEN_AMOUNT);
    }

    function test_onBeforeLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        pool.pause();

        vm.prank(MARKET);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onBeforeLoanPayment(LOAN_ID, TOKEN_AMOUNT);
    }

    // /************************************************
    //  *  Test `onAfterLoanPayment` function
    //  ***********************************************/


    // function test_onAfterLoanPayment_CreditLineBalance() public {
    //     pool.mockLoanCreditLine(LOAN_ID, LINE);
    //     pool.mockCreditLineBalance(LINE, TOKEN_AMOUNT);

    //     assertEq(pool.getCreditLine(LOAN_ID), LINE);
    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT);

    //     vm.prank(MARKET);
    //     assertEq(pool.onAfterLoanPayment(LOAN_ID, TOKEN_AMOUNT), true);

    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT * 2);
    // }

    // function test_onAfterLoanPayment_NonCreditLineBalance() public {
    //     pool.mockLoanCreditLine(LOAN_ID, LINE);
    //     pool.mockCreditLineBalance(LINE, TOKEN_AMOUNT);

    //     assertEq(pool.getCreditLine(LOAN_ID), LINE);
    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT);

    //     vm.prank(MARKET);
    //     assertEq(pool.onAfterLoanPayment(NONEXISTENT_LOAN_ID, TOKEN_AMOUNT), true);

    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT);
    // }

    // function test_onAfterLoanPayment_Revert_IfCallerNotMarket() public {
    //     vm.prank(ATTACKER);
    //     vm.expectRevert(Error.Unauthorized.selector);
    //     pool.onAfterLoanPayment(LOAN_ID, TOKEN_AMOUNT);
    // }

    // function test_onAfterLoanPayment_Revert_IfContractIsPaused() public {
    //     vm.prank(LENDER);
    //     pool.pause();

    //     vm.prank(MARKET);
    //     vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
    //     pool.onAfterLoanPayment(LOAN_ID, TOKEN_AMOUNT);
    // }

    // /************************************************
    //  *  Test `getTokenBalance` function
    //  ***********************************************/

    // function test_getTokenBalance() public {
    //     assertEq(pool.getTokenBalance(LINE), 0);
    //     assertEq(pool.getTokenBalance(address(token)), 0);
    //     assertEq(pool.getTokenBalance(NONEXISTENT_TOKEN_SOUTRCE), 0);

    //     pool.mockCreditLineBalance(LINE, TOKEN_AMOUNT + 1);
    //     token.mint(address(pool), TOKEN_AMOUNT + 2);

    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT + 1);
    //     assertEq(pool.getTokenBalance(address(token)), TOKEN_AMOUNT + 2);
    //     assertEq(pool.getTokenBalance(NONEXISTENT_TOKEN_SOUTRCE), 0);
    // }

    // /************************************************
    //  *  Test `getCreditLine` function
    //  ***********************************************/

    // function test_getCreditLine() public {
    //     pool.mockLoanCreditLine(LOAN_ID, LINE);
    //     assertEq(pool.getCreditLine(LOAN_ID), LINE);
    // }

    // /************************************************
    //  *  Tests view functions
    //  ***********************************************/

    // function test_market() public {
    //     assertEq(pool.market(), MARKET);
    // }

    // function test_lender() public {
    //     assertEq(pool.lender(), LENDER);
    // }

    // function test_kind() public {
    //     assertEq(pool.kind(), KIND);
    // }

    // /************************************************
    //  *  Test mock functions
    //  ***********************************************/

    // function test_mockCreditLineToken() public {
    //     assertEq(pool.getCreditLineToken(LINE), address(0));
    //     pool.mockCreditLineToken(LINE, address(token));
    //     assertEq(pool.getCreditLineToken(LINE), address(token));
    // }

    // function test_mockLoanCreditLine() public {
    //     assertEq(pool.getCreditLine(LOAN_ID), address(0));
    //     pool.mockLoanCreditLine(LOAN_ID, LINE);
    //     assertEq(pool.getCreditLine(LOAN_ID), LINE);
    // }

    // function test_mockCreditLineBalance() public {
    //     assertEq(pool.getTokenBalance(LINE), 0);
    //     pool.mockCreditLineBalance(LINE, TOKEN_AMOUNT);
    //     assertEq(pool.getTokenBalance(LINE), TOKEN_AMOUNT);
    // }

    // function test_mockLoanInitialBorrowAmount() public {
    //     assertEq(pool.getLoanInitialBorrowAmount(LOAN_ID), 0);
    //     pool.mockLoanInitialBorrowAmount(LOAN_ID, TOKEN_AMOUNT);
    //     assertEq(pool.getLoanInitialBorrowAmount(LOAN_ID), TOKEN_AMOUNT);
    // }
}

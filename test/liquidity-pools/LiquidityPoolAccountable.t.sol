// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";

import { ERC20Mock } from "src/mocks/ERC20Mock.sol";
import { CreditLineMock } from "src/mocks/CreditLineMock.sol";
import { LendingMarketMock } from "src/mocks/LendingMarketMock.sol";

import { ILiquidityPoolAccountable } from "src/common/interfaces/ILiquidityPoolAccountable.sol";
import { LiquidityPoolAccountable } from "src/liquidity-pools/LiquidityPoolAccountable.sol";

/// @title LiquidityPoolAccountableTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolAccountable` contract.
contract LiquidityPoolAccountableTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event AdminConfigured(address indexed account, bool adminStatus);
    event Deposit(uint256 amount);
    event Withdrawal(uint256 borrowableAmount, uint256 addonAmount);
    event Rescue(address indexed token, uint256 amount);
    event AutoRepayment(uint256 numberOfLoans);
    event RepayLoanCalled(uint256 indexed loanId, uint256 repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    ERC20Mock private token;
    CreditLineMock private creditLine;
    LendingMarketMock private lendingMarket;
    LiquidityPoolAccountable private liquidityPool;

    address private constant ADMIN = address(bytes20(keccak256("admin")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant PAUSER = address(bytes20(keccak256("pauser")));
    address private constant DEPLOYER = address(bytes20(keccak256("deployer")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));
    address private constant TOKEN_SOURCE_NONEXISTENT = address(bytes20(keccak256("token_source_nonexistent")));

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 private constant LOAN_ID_1 = 1;
    uint256 private constant LOAN_ID_2 = 2;
    uint256 private constant LOAN_ID_3 = 3;
    uint256 private constant LOAN_ID_NONEXISTENT = 999_999_999;

    uint64 private constant DEPOSIT_AMOUNT_1 = 100;
    uint64 private constant DEPOSIT_AMOUNT_2 = 200;
    uint64 private constant DEPOSIT_AMOUNT_3 = 300;
    uint64 private constant ADDON_AMOUNT = 25;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        vm.startPrank(DEPLOYER);
        token = new ERC20Mock();
        creditLine = new CreditLineMock();
        creditLine.mockTokenAddress(address(token));
        lendingMarket = new LendingMarketMock();
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(LENDER, address(lendingMarket), address(token));
        vm.stopPrank();

        vm.startPrank(LENDER);
        liquidityPool.grantRole(PAUSER_ROLE, PAUSER);
        liquidityPool.grantRole(ADMIN_ROLE, ADMIN);
        vm.stopPrank();
    }

    function configureLender(uint256 amount) private {
        vm.startPrank(LENDER);
        token.mint(LENDER, amount);
        token.approve(address(liquidityPool), amount);
        vm.stopPrank();
    }

    function getBatchLoanData() private pure returns (uint256[] memory, uint256[] memory) {
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

    function initLoanState() private view returns (Loan.State memory) {
        return Loan.State({
            token: address(token),
            borrower: address(0),
            programId: 0,
            durationInPeriods: 0,
            interestRatePrimary: 0,
            interestRateSecondary: 0,
            startTimestamp: 0,
            freezeTimestamp: 0,
            trackedTimestamp: 0,
            borrowAmount: 0,
            trackedBalance: 0,
            repaidAmount: 0,
            addonAmount: 0
        });
    }

    // -------------------------------------------- //
    //  Test initializer                            //
    // -------------------------------------------- //

    function test_initializer() public {
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(LENDER, address(lendingMarket), address(token));
        assertEq(liquidityPool.market(), address(lendingMarket));
        assertEq(liquidityPool.token(), address(token));
        assertEq(liquidityPool.hasRole(OWNER_ROLE, LENDER), true);
    }

    function test_initializer_Revert_IfMarketIsZeroAddress() public {
        liquidityPool = new LiquidityPoolAccountable();
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.initialize(LENDER, address(0), address(token));
    }

    function test_initializer_Revert_IfLenderIsZeroAddress() public {
        liquidityPool = new LiquidityPoolAccountable();
        vm.expectRevert(Error.ZeroAddress.selector);
        liquidityPool.initialize(address(0), address(lendingMarket), address(token));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(LENDER, address(lendingMarket), address(token));
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        liquidityPool.initialize(LENDER, address(lendingMarket), address(token));
    }

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

    function test_pause() public {
        assertEq(liquidityPool.paused(), false);
        vm.prank(PAUSER);
        liquidityPool.pause();
        assertEq(liquidityPool.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(PAUSER);
        liquidityPool.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, PAUSER_ROLE)
        );
        liquidityPool.pause();
    }

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

    function test_unpause() public {
        vm.startPrank(PAUSER);
        assertEq(liquidityPool.paused(), false);
        liquidityPool.pause();
        assertEq(liquidityPool.paused(), true);
        liquidityPool.unpause();
        assertEq(liquidityPool.paused(), false);
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(liquidityPool.paused(), false);
        vm.prank(PAUSER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        liquidityPool.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(PAUSER);
        liquidityPool.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, PAUSER_ROLE)
        );
        liquidityPool.unpause();
    }

    // -------------------------------------------- //
    //  Test `deposit` function                     //
    // -------------------------------------------- //

    function test_deposit() public {
        configureLender(DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), 0);

        (uint256 borrowable, uint256 addons) = liquidityPool.getBalances();
        assertEq(borrowable, 0);
        assertEq(addons, 0);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Deposit(DEPOSIT_AMOUNT_1);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);
        assertEq(token.allowance(address(liquidityPool), address(lendingMarket)), type(uint256).max);

        (borrowable, addons) = liquidityPool.getBalances();
        assertEq(borrowable, DEPOSIT_AMOUNT_1);
        assertEq(addons, 0);
    }

    function test_deposit_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);
    }

    function test_deposit_Revert_IfDepositAmountIsZero() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.deposit(0);
    }

    // -------------------------------------------- //
    //  Test `withdraw` function                    //
    // -------------------------------------------- //

    function prepareWithdraw() private returns (uint256, uint256) {
        uint256 depositAmount = DEPOSIT_AMOUNT_1 + DEPOSIT_AMOUNT_2 + ADDON_AMOUNT;
        configureLender(depositAmount);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(depositAmount);

        vm.prank(address(lendingMarket));
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);

        return (DEPOSIT_AMOUNT_2, ADDON_AMOUNT);
    }

    function test_withdraw() public {
        (uint256 borrowable, uint256 addons) = prepareWithdraw();

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, borrowable);
        assertEq(addonsBalance, addons);
        assertEq(token.balanceOf(LENDER), 0);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdrawal(0, 1);
        liquidityPool.withdraw(0, 1);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, borrowable);
        assertEq(addonsBalance, addons - 1);
        assertEq(token.balanceOf(LENDER), 1);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Withdrawal(1, 0);
        liquidityPool.withdraw(1, 0);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, borrowable - 1);
        assertEq(addonsBalance, addons - 1);
        assertEq(token.balanceOf(LENDER), 2);
    }

    function test_withdraw_Revert_IfCallerNotOwner() public {
        (uint256 borrowable, uint256 addons) = prepareWithdraw();
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        liquidityPool.withdraw(borrowable, addons);
    }

    function test_withdraw_Revert_IfWithdrawAmountIsZero() public {
        prepareWithdraw();
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        liquidityPool.withdraw(0, 0);
    }

    function test_withdraw_Revert_CreditLineBalance_InsufficientBalance_Borrowable() public {
        (uint256 borrowable, uint256 addons) = prepareWithdraw();
        vm.prank(LENDER);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(borrowable + 1, addons);
    }

    function test_withdraw_Revert_CreditLineBalance_InsufficientBalance_Addons() public {
        (uint256 borrowable, uint256 addons) = prepareWithdraw();
        vm.prank(LENDER);
        vm.expectRevert(LiquidityPoolAccountable.InsufficientBalance.selector);
        liquidityPool.withdraw(borrowable, addons + 1);
    }

    // -------------------------------------------- //
    //  Test `rescue` function                      //
    // -------------------------------------------- //

    function test_rescue() public {
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(LENDER), 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit Rescue(address(token), DEPOSIT_AMOUNT_1);
        liquidityPool.rescue(address(token), DEPOSIT_AMOUNT_1);

        assertEq(token.balanceOf(LENDER), DEPOSIT_AMOUNT_1);
        assertEq(token.balanceOf(address(liquidityPool)), 0);
    }

    function test_rescue_Revert_IfCallerNotOwner() public {
        token.mint(address(liquidityPool), DEPOSIT_AMOUNT_1);
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        liquidityPool.rescue(address(token), DEPOSIT_AMOUNT_1);
    }

    // -------------------------------------------- //
    //  Test `autoRepay` function                   //
    // -------------------------------------------- //

    function test_autoRepay() public {
        (uint256[] memory loanIds, uint256[] memory amounts) = getBatchLoanData();

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit AutoRepayment(loanIds.length);

        for (uint256 i = 0; i < loanIds.length; i++) {
            vm.expectEmit(true, true, true, true, address(lendingMarket));
            emit RepayLoanCalled(loanIds[i], amounts[i]);
        }

        vm.stopPrank();
        vm.prank(ADMIN);
        liquidityPool.autoRepay(loanIds, amounts);
    }

    function test_deposit_Revert_IfCallerNotAdmin() public {
        (uint256[] memory loanIds, uint256[] memory amounts) = getBatchLoanData();

        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, ADMIN_ROLE)
        );
        liquidityPool.autoRepay(loanIds, amounts);
    }

    function test_autoRepay_Revert_IfArrayLengthMismatch() public {
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
        configureLender(DEPOSIT_AMOUNT_1);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1 - ADDON_AMOUNT;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(LENDER);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeLoanTaken(LOAN_ID_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, ADDON_AMOUNT);
    }

    function test_onBeforeLoanTaken_Revert_IfContractIsPaused() public {
        vm.prank(PAUSER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);
    }

    function test_onBeforeLoanTaken_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);
    }

    // -------------------------------------------- //
    //  Test `onAfterLoanPayment` function          //
    // -------------------------------------------- //

    function prepareRepayment() private {
        configureLender(DEPOSIT_AMOUNT_1);

        vm.prank(LENDER);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1 - ADDON_AMOUNT;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);
    }

    function test_onAfterLoanPayment_ExistentLoan() public {
        prepareRepayment();

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onBeforeLoanTaken(LOAN_ID_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, ADDON_AMOUNT);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, ADDON_AMOUNT);
    }

    function test_onAfterLoanPayment_NonNonExistentLoan() public {
        prepareRepayment();

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanPayment(LOAN_ID_NONEXISTENT, DEPOSIT_AMOUNT_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1 + DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);
    }

    function test_onAfterLoanPayment_Revert_IfContractIsPaused() public {
        vm.prank(PAUSER);
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
    //  Test `onAfterLoanRevocation` function     //
    // -------------------------------------------- //

    function test_onAfterLoanRevocation_RepaidAmountLessThanBorrowAmount() public {
        configureLender(DEPOSIT_AMOUNT_1);

        vm.prank(LENDER);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1 - ADDON_AMOUNT;
        loan.repaidAmount = DEPOSIT_AMOUNT_1 / 2;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(address(lendingMarket));
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, ADDON_AMOUNT);

        vm.prank(address(lendingMarket));
        liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1 / 2);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1 / 2);
        assertEq(addonsBalance, ADDON_AMOUNT);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanRevocation(LOAN_ID_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);
    }

    function test_onAfterLoanRevocation_RepaidAmountGreaterThanBorrowAmount() public {
        configureLender(DEPOSIT_AMOUNT_1);

        vm.prank(LENDER);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1 - ADDON_AMOUNT;
        loan.repaidAmount = DEPOSIT_AMOUNT_1 * 2;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(address(lendingMarket));
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, ADDON_AMOUNT);

        vm.prank(address(lendingMarket));
        liquidityPool.onAfterLoanPayment(LOAN_ID_1, DEPOSIT_AMOUNT_1 * 2);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1 * 2);
        assertEq(addonsBalance, ADDON_AMOUNT);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanRevocation(LOAN_ID_1), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);
    }

    function test_onAfterLoanRevocation_NonExistentLoan() public {
        prepareRepayment();

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);

        vm.prank(address(lendingMarket));
        assertEq(liquidityPool.onAfterLoanRevocation(LOAN_ID_NONEXISTENT), true);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);
    }

    function test_onAfterLoanRevocation_Revert_IfContractIsPaused() public {
        vm.prank(PAUSER);
        liquidityPool.pause();

        vm.prank(address(lendingMarket));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        liquidityPool.onAfterLoanRevocation(LOAN_ID_1);
    }

    function test_onAfterLoanRevocation_Revert_IfCallerNotMarket() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        liquidityPool.onAfterLoanRevocation(LOAN_ID_1);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getBalances() public {
        configureLender(DEPOSIT_AMOUNT_1);

        (uint256 borrowableBalance, uint256 addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, 0);
        assertEq(token.balanceOf(address(liquidityPool)), 0);

        vm.prank(LENDER);
        liquidityPool.deposit(DEPOSIT_AMOUNT_1);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, DEPOSIT_AMOUNT_1);
        assertEq(addonsBalance, 0);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT_1);

        Loan.State memory loan = initLoanState();
        loan.borrowAmount = DEPOSIT_AMOUNT_1 - ADDON_AMOUNT;
        loan.addonAmount = ADDON_AMOUNT;
        lendingMarket.mockLoanState(LOAN_ID_1, loan);

        vm.prank(address(lendingMarket));
        liquidityPool.onBeforeLoanTaken(LOAN_ID_1);

        (borrowableBalance, addonsBalance) = liquidityPool.getBalances();
        assertEq(borrowableBalance, 0);
        assertEq(addonsBalance, ADDON_AMOUNT);
    }

    function test_market() public {
        assertEq(liquidityPool.market(), address(lendingMarket));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "forge-std/Test.sol";

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Interest } from "src/common/libraries/Interest.sol";
import { Constants } from "src/common/libraries/Constants.sol";
import { Error } from "src/common/libraries/Error.sol";

import { ICreditLineConfigurable } from "src/common/interfaces/ICreditLineConfigurable.sol";
import { ILiquidityPoolAccountable } from "src/common/interfaces/ILiquidityPoolAccountable.sol";
import { ERC20Mock } from "src/mocks/ERC20Mock.sol";

import { LendingMarket } from "src/LendingMarket.sol";
import { CreditLineConfigurable } from "src/credit-lines/CreditLineConfigurable.sol";
import { LiquidityPoolAccountable } from "src/liquidity-pools/LiquidityPoolAccountable.sol";
import { LendingRegistry } from "src/LendingRegistry.sol";
import { LiquidityPoolFactory } from "src/liquidity-pools/LiquidityPoolFactory.sol";
import { CreditLineFactory } from "src/credit-lines/CreditLineFactory.sol";

contract SmartContractIntegration is Test {
    ERC20Mock private token;
    LendingMarket private lendingMarket;
    LendingRegistry private lendingRegistry;
    CreditLineConfigurable private creditLine;
    LiquidityPoolAccountable private liquidityPool;
    CreditLineFactory private creditLineFactory;
    LiquidityPoolFactory private liquidityPoolFactory;

    CreditLineConfigurable.CreditLineConfig private creditLineConfig;
    CreditLineConfigurable.BorrowerConfig private borrowerConfig;

    address private constant OWNER = address(bytes20(keccak256("owner")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant ADMIN = address(bytes20(keccak256("admin")));
    address private constant BORROWER = address(bytes20(keccak256("borrower")));

    uint256 private constant MINT_AMOUNT = 1000000;
    uint256 private constant DEPOSIT_AMOUNT = 1000;
    uint256 private constant BORROW_AMOUNT = 100;
    uint256 private constant REPAY_AMOUNT = 100;
    uint256 private constant DURATION_IN_PERIODS = 10;
    uint64 private constant MIN_BORROW_AMOUNT = 1;
    uint64 private constant MAX_BORROW_AMOUNT = 10000;
    uint32 private constant MIN_DURATION_IN_PERIODS = 1;
    uint32 private constant MAX_DURATION_IN_PERIODS = 10000;
    uint32 private constant INTEREST_RATE = 10;
    uint8 private constant KIND = 1;

    address private constant EXPECTED_CREDIT_LINE_ADDRESS = 0xBe4457Ba5FD23cDbb64969545a104c042b9D661D;
    address private constant EXPECTED_LIQUIDITY_POOL_ADDRESS = 0x34266Dd94CB1C181FF4445224711Cd2A1CF9B2ec;

    function createBorrowerConfig()
    private
    pure
    returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: MIN_BORROW_AMOUNT,
            maxBorrowAmount: MAX_BORROW_AMOUNT,
            minDurationInPeriods: MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: MAX_DURATION_IN_PERIODS,
            interestRatePrimary: INTEREST_RATE,
            interestRateSecondary: INTEREST_RATE,
            addonFixedRate: 0,
            addonPeriodRate: 0,
            interestFormula: Interest.Formula.Compound,
            borrowPolicy: ICreditLineConfigurable.BorrowPolicy.Keep,
            expiration: type(uint32).max
        });
    }

    function createCreditLineConfig()
    private
    view
    returns (ICreditLineConfigurable.CreditLineConfig memory)
    {
        return ICreditLineConfigurable.CreditLineConfig({
            treasury: address(liquidityPool),
            minDurationInPeriods: 0,
            maxDurationInPeriods: type(uint32).max,
            minBorrowAmount: 0,
            maxBorrowAmount: type(uint64).max,
            minInterestRatePrimary: 0,
            maxInterestRatePrimary: type(uint32).max,
            minInterestRateSecondary: 0,
            maxInterestRateSecondary: type(uint32).max,
            minAddonFixedRate: 0,
            maxAddonFixedRate: type(uint32).max,
            minAddonPeriodRate: 0,
            maxAddonPeriodRate: type(uint32).max
        });
    }

    function setUp() public {
        vm.startPrank(OWNER);

        // Deploy token
        token = new ERC20Mock();

        // Deploy market
        lendingMarket = new LendingMarket();
        lendingMarket.initialize("NAME", "SYMBOL");

        // Deploy credit line
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(address(lendingMarket), LENDER, address(token));

        // Deploy liquidity pool
        liquidityPool = new LiquidityPoolAccountable();
        liquidityPool.initialize(address(lendingMarket), LENDER);

        // Register credit line and liquidity pool
        lendingMarket.registerCreditLine(LENDER, address(creditLine));
        lendingMarket.registerLiquidityPool(LENDER, address(liquidityPool));

        // Configure token
        token.mint(LENDER, DEPOSIT_AMOUNT);
        token.mint(BORROWER, MINT_AMOUNT);
        vm.stopPrank();

        // Configure liquidity pool and credit line
        vm.startPrank(LENDER);
        token.approve(address(liquidityPool), type(uint256).max);
        liquidityPool.deposit(address(creditLine), DEPOSIT_AMOUNT);
        creditLine.configureCreditLine(createCreditLineConfig());
        creditLine.configureAdmin(ADMIN, true);
        lendingMarket.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
        vm.stopPrank();

        // Configure borrower
        vm.startPrank(ADMIN);
        creditLine.configureBorrower(BORROWER, createBorrowerConfig());
        vm.stopPrank();

        // Configure allowance
        vm.startPrank(BORROWER);
        token.approve(address(lendingMarket), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(OWNER);
        // Deploy lending registry
        lendingRegistry = new LendingRegistry();
        lendingRegistry.initialize(address(lendingMarket));

        // Deploy factory contracts
        creditLineFactory = new CreditLineFactory();
        creditLineFactory.initialize(address(lendingRegistry));

        liquidityPoolFactory = new LiquidityPoolFactory();
        liquidityPoolFactory.initialize(address(lendingRegistry));

        // Register factories
        lendingRegistry.setCreditLineFactory(address(creditLineFactory));
        lendingRegistry.setLiquidityPoolFactory(address(liquidityPoolFactory));

        // Set lending registry
        lendingMarket.setRegistry(address(lendingRegistry));

        vm.stopPrank();

        skip(Constants.NEGATIVE_TIME_OFFSET);
    }

    function test_takeLoan_Integrations_If_BorrowPolicy_Keep() public {
        ICreditLineConfigurable.BorrowerConfig memory configBeforeLoan = creditLine.getBorrowerConfiguration(BORROWER);

        vm.prank(BORROWER);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        ICreditLineConfigurable.BorrowerConfig memory configAfterLoan = creditLine.getBorrowerConfiguration(BORROWER);
        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterLoan = liquidityPool.getCreditLineBalance(address(creditLine));

        // check onBeforeLoanTaken hook on CreditLine
        assertEq(configBeforeLoan.maxBorrowAmount, configAfterLoan.maxBorrowAmount);

        // check safeTransferFrom function on Token
        assertEq(token.balanceOf(BORROWER), MINT_AMOUNT + BORROW_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT - BORROW_AMOUNT);

        // check onAfterLoanTaken hook on LiquidityPool
        assertEq(creditLineBalanceAfterLoan.borrowable, DEPOSIT_AMOUNT - BORROW_AMOUNT);
    }

    function test_takeLoan_Integrations_If_BorrowPolicy_Reset() public {
        vm.startPrank(ADMIN);
        ICreditLineConfigurable.BorrowerConfig memory config = createBorrowerConfig();
        config.borrowPolicy = ICreditLineConfigurable.BorrowPolicy.Reset;
        creditLine.configureBorrower(BORROWER, config);
        vm.stopPrank();

        vm.prank(BORROWER);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        ICreditLineConfigurable.BorrowerConfig memory configAfterLoan = creditLine.getBorrowerConfiguration(BORROWER);
        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterLoan = liquidityPool.getCreditLineBalance(address(creditLine));

        // check onBeforeLoanTaken hook on CreditLine
        assertEq(configAfterLoan.maxBorrowAmount, 0); // reset

        // check safeTransferFrom function on Token
        assertEq(token.balanceOf(BORROWER), MINT_AMOUNT + BORROW_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT - BORROW_AMOUNT);

        // check onAfterLoanTaken hook on LiquidityPool
        assertEq(creditLineBalanceAfterLoan.borrowable, DEPOSIT_AMOUNT - BORROW_AMOUNT);
    }

    function test_takeLoan_Integrations_If_BorrowPolicy_Decrease() public {
        vm.startPrank(ADMIN);
        ICreditLineConfigurable.BorrowerConfig memory configBeforeLoan = createBorrowerConfig();
        configBeforeLoan.borrowPolicy = ICreditLineConfigurable.BorrowPolicy.Decrease;
        creditLine.configureBorrower(BORROWER, configBeforeLoan);
        vm.stopPrank();

        vm.prank(BORROWER);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        ICreditLineConfigurable.BorrowerConfig memory configAfterLoan = creditLine.getBorrowerConfiguration(BORROWER);
        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterLoan = liquidityPool.getCreditLineBalance(address(creditLine));

        // check onBeforeLoanTaken hook on CreditLine
        assertEq(configAfterLoan.maxBorrowAmount, configBeforeLoan.maxBorrowAmount - BORROW_AMOUNT); // decrease

        // check safeTransferFrom function on Token
        assertEq(token.balanceOf(BORROWER), MINT_AMOUNT + BORROW_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT - BORROW_AMOUNT);

        // check onAfterLoanTaken hook on LiquidityPool
        assertEq(creditLineBalanceAfterLoan.borrowable, DEPOSIT_AMOUNT - BORROW_AMOUNT);
    }

    function test_takeLoan_Revert_If_CreditLineIsPaused() public {
        vm.prank(LENDER);
        creditLine.pause();

        vm.prank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);
    }

    function test_takeLoan_Revert_If_BorrowerConfigurationExpired() public {
        skip(type(uint32).max);

        vm.prank(BORROWER);
        vm.expectRevert(CreditLineConfigurable.BorrowerConfigurationExpired.selector);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);
    }

    function test_takeLoan_Revert_If_InvalidBorrowAmount() public {
        vm.startPrank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        lendingMarket.takeLoan(address(creditLine), MAX_BORROW_AMOUNT + 1, DURATION_IN_PERIODS);

        vm.expectRevert(Error.InvalidAmount.selector);
        lendingMarket.takeLoan(address(creditLine), MIN_BORROW_AMOUNT - 1, DURATION_IN_PERIODS);
    }

    function test_takeLoan_Revert_If_LoanDurationOutOfRange() public {
        vm.startPrank(BORROWER);
        vm.expectRevert(CreditLineConfigurable.LoanDurationOutOfRange.selector);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, MAX_DURATION_IN_PERIODS + 1);

        vm.expectRevert(CreditLineConfigurable.LoanDurationOutOfRange.selector);
        lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, MIN_DURATION_IN_PERIODS - 1);
    }

    function test_takeLoan_Revert_If_TokenBalanceInsufficient() public {
        vm.startPrank(BORROWER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                address(liquidityPool), DEPOSIT_AMOUNT, DEPOSIT_AMOUNT + 1
            )
        );
        lendingMarket.takeLoan(address(creditLine), DEPOSIT_AMOUNT + 1, DURATION_IN_PERIODS);
    }

    function test_repayLoan_Integrations() public {
        vm.startPrank(BORROWER);
        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterLoan = liquidityPool.getCreditLineBalance(address(creditLine));
        uint256 borrowerBalanceBeforeRepayment = token.balanceOf(BORROWER);

        lendingMarket.repayLoan(loanId, REPAY_AMOUNT);

        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterRepayment = liquidityPool.getCreditLineBalance(address(creditLine));
        uint256 borrowerBalanceAfterRepayment = token.balanceOf(BORROWER);

        // check safeTransferFrom function on Token
        assertEq(borrowerBalanceAfterRepayment, borrowerBalanceBeforeRepayment - REPAY_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT);

        // check onAfterLoanPayment hook on liquidityPool
        assertEq(creditLineBalanceAfterLoan.borrowable, creditLineBalanceAfterRepayment.borrowable - REPAY_AMOUNT);
    }

    function test_repayLoan_Revert_If_LiquidityPoolIsPaused() public {
        vm.prank(BORROWER);
        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        vm.prank(LENDER);
        liquidityPool.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.repayLoan(loanId, REPAY_AMOUNT);
    }

    function test_revokeLoan_Integrations() public {
        vm.startPrank(BORROWER);
        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        lendingMarket.revokeLoan(loanId);
        ILiquidityPoolAccountable.CreditLineBalance memory creditLineBalanceAfterRevoke = liquidityPool.getCreditLineBalance(address(creditLine));

        // check safeTransferFrom hook
        assertEq(token.balanceOf(BORROWER), MINT_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), DEPOSIT_AMOUNT);

        // check hook onAfterLoanRevocation on LiquidityPool
        assertEq(creditLineBalanceAfterRevoke.borrowable, DEPOSIT_AMOUNT);
    }

    function test_revokeLoan_Revert_If_LiquidityPoolIsPaused() public {
        vm.prank(BORROWER);
        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        vm.prank(LENDER);
        liquidityPool.pause();

        vm.prank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        lendingMarket.revokeLoan(loanId);
    }

    function test_revokeLoan_Revert_If_TokenBalanceInsufficient() public {
        vm.startPrank(BORROWER);
        uint256 loanId = lendingMarket.takeLoan(address(creditLine), BORROW_AMOUNT, DURATION_IN_PERIODS);

        token.transfer(LENDER, token.balanceOf(BORROWER));

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                BORROWER, 0, BORROW_AMOUNT
            )
        );
        lendingMarket.revokeLoan(loanId);
    }

    function test_createCreditLine_Integrations() public {
        vm.startPrank(OWNER);

        lendingRegistry.createCreditLine(KIND, address(token));

        // check registerCreditLine function on lending market
        assertEq(lendingMarket.getCreditLineLender(EXPECTED_CREDIT_LINE_ADDRESS), OWNER);
    }

    function test_createCreditLine_Revert_If_UnsupportedKind() public {
        vm.startPrank(OWNER);

        vm.expectRevert(CreditLineFactory.UnsupportedKind.selector);
        lendingRegistry.createCreditLine(KIND + 1, address(token));
    }

    function test_createLiquidityPool_Integrations() public {
        vm.startPrank(OWNER);

        lendingRegistry.createLiquidityPool(KIND);

        // check registerLiquidityPool function on lending market
        assertEq(lendingMarket.getLiquidityPoolLender(EXPECTED_LIQUIDITY_POOL_ADDRESS), OWNER);
    }

    function test_createLiquidityPool_Revert_If_UnsupportedKind() public {
        vm.startPrank(OWNER);

        vm.expectRevert(LiquidityPoolFactory.UnsupportedKind.selector);
        lendingRegistry.createLiquidityPool(KIND + 1);
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";
import { SafeCast } from "src/common/libraries/SafeCast.sol";

import { ERC20Mock } from "src/mocks/ERC20Mock.sol";
import { CreditLineMock } from "src/mocks/CreditLineMock.sol";
import { LiquidityPoolMock } from "src/mocks/LiquidityPoolMock.sol";

import { ICreditLineConfigurable } from "src/common/interfaces/ICreditLineConfigurable.sol";
import { LendingMarket } from "src/LendingMarket.sol";

/// @title LendingMarketTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LendingMarket` contract.
contract LendingMarketTest is Test {
    using SafeCast for uint256;

    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnBeforeLoanRevocationCalled(uint256 indexed loanId);
    event OnAfterLoanRevocationCalled(uint256 indexed loanId);

    event MarketRegistryChanged(address indexed newRegistry, address indexed oldRegistry);
    event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);
    event CreditLineRegistered(address indexed lender, address indexed creditLine);

    event LiquidityPoolLenderUpdated(
        address indexed liquidityPool,
        address indexed newLender,
        address indexed oldLender
    );

    event CreditLineLenderUpdated(
        address indexed creditLine,
        address indexed newLender,
        address indexed oldLender
    );

    event LoanTaken(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods
    );
    event LoanRepayment(
        uint256 indexed loanId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 outstandingBalance
    );
    event LoanRevoked(uint256 indexed loanId);

    event LoanFrozen(uint256 indexed loanId);
    event LoanUnfrozen(uint256 indexed loanId);

    event LoanDurationUpdated(
        uint256 indexed loanId,
        uint256 indexed newDuration,
        uint256 indexed oldDuration
    );
    event LoanInterestRatePrimaryUpdated(
        uint256 indexed loanId,
        uint256 indexed newInterestRate,
        uint256 indexed oldInterestRate
    );
    event LoanInterestRateSecondaryUpdated(
        uint256 indexed loanId,
        uint256 indexed newInterestRate,
        uint256 indexed oldInterestRate
    );

    event LiquidityPoolAssignedToCreditLine(
        address indexed creditLine,
        address indexed newLiquidityPool,
        address indexed oldLiquidityPool
    );
    event LenderAliasConfigured(
        address indexed lender,
        address indexed account,
        bool isAlias
    );

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    ERC20Mock private token;
    LendingMarket private market;
    CreditLineMock private creditLine;
    LiquidityPoolMock private liquidityPool;

    address private constant OWNER = address(bytes20(keccak256("owner")));
    address private constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address private constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));
    address private constant BORROWER_1 = address(bytes20(keccak256("borrower_1")));
    address private constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address private constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address private constant REGISTRY_1 = address(bytes20(keccak256("registry_1")));
    address private constant REGISTRY_2 = address(bytes20(keccak256("registry_2")));
    address private constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    address private constant LOAN_TREASURY = address(bytes20(keccak256("loan_treasury")));
    address private constant LENDER_1_ALIAS = address(bytes20(keccak256("lender_1_alias")));
    address private constant LIQUIDITY_POOL_1 = address(bytes20(keccak256("liquidity_pool_1")));
    address private constant LIQUIDITY_POOL_2 = address(bytes20(keccak256("liquidity_pool_2")));

    uint64 private constant ADDON_AMOUNT = 100;
    uint64 private constant BORROW_AMOUNT = 100;
    uint32 private constant DURATION_IN_PERIODS = 30;
    uint256 private constant LOAN_ID_NONEXISTENT = 999_999_999;
    uint256 private constant INIT_BLOCK_TIMESTAMP = CREDIT_LINE_CONFIG_PERIOD_IN_SECONDS + 1;

    uint64 private constant CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT = 400;
    uint64 private constant CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT = 900;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY = 3;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY = 7;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY = 4;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY = 8;
    uint32 private constant CREDIT_LINE_CONFIG_INTEREST_RATE_FACTOR = 1000;
    uint32 private constant CREDIT_LINE_CONFIG_PERIOD_IN_SECONDS = 600;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS = 50;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS = 200;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_RATE = 10;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_RATE = 50;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_RATE = 10;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_RATE = 50;
    uint16 private constant CREDIT_LINE_CONFIG_MIN_REVOCATION_PERIODS = 2;
    uint16 private constant CREDIT_LINE_CONFIG_MAX_REVOCATION_PERIODS = 4;

    uint32 private constant BORROWER_CONFIG_ADDON_FIXED_RATE = 15;
    uint32 private constant BORROWER_CONFIG_ADDON_PERIOD_RATE = 20;
    uint32 private constant BORROWER_CONFIG_MIN_DURATION_IN_PERIODS = 25;
    uint32 private constant BORROWER_CONFIG_MAX_DURATION_IN_PERIODS = 35;
    uint32 private constant BORROWER_CONFIG_DURATION = 1000;
    uint64 private constant BORROWER_CONFIG_MIN_BORROW_AMOUNT = 500;
    uint64 private constant BORROWER_CONFIG_MAX_BORROW_AMOUNT = 800;
    uint32 private constant BORROWER_CONFIG_INTEREST_RATE_PRIMARY = 5;
    uint32 private constant BORROWER_CONFIG_INTEREST_RATE_SECONDARY = 6;
    uint16 private constant BORROWER_CONFIG_REVOCATION_PERIODS = 3;
    bool private constant BORROWER_CONFIG_AUTOREPAYMENT = true;
    Interest.Formula private constant BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy private constant BORROWER_CONFIG_BORROW_POLICY_DECREASE =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    bool private canOverrideAutoRepayment = false;
    bool private overrideAutoRepayment = false;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        token = new ERC20Mock();
        creditLine = new CreditLineMock();
        liquidityPool = new LiquidityPoolMock();

        market = new LendingMarket();
        market.initialize("NAME", "SYMBOL");
        market.setRegistry(REGISTRY_1);
        market.transferOwnership(OWNER);

        skip(INIT_BLOCK_TIMESTAMP);
    }

    function configureMarket() private {
        vm.startPrank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.stopPrank();

        vm.startPrank(LENDER_1);
        market.configureAlias(LENDER_1_ALIAS, true);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
        vm.stopPrank();

        vm.prank(address(liquidityPool));
        token.approve(address(market), type(uint256).max);
    }

    function mockLoanTerms() private returns (uint256, Loan.Terms memory) {
        Loan.Terms memory terms = initLoanTerms(address(token));

        if (canOverrideAutoRepayment) {
            terms.autoRepayment = overrideAutoRepayment;
        }

        terms.treasury = address(liquidityPool);

        creditLine.mockLoanTerms(BORROWER_1, BORROW_AMOUNT, terms);

        return (BORROW_AMOUNT, terms);
    }

    function createActiveLoan(uint256 skipPeriodsAfterCreated) private returns (uint256) {
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        vm.prank(BORROWER_1);
        uint256 loanId = market.takeLoan(address(creditLine), borrowAmount, terms.durationInPeriods);

        Loan.State memory loan = market.getLoanState(loanId);
        skip(loan.periodInSeconds * skipPeriodsAfterCreated);

        return loanId;
    }

    function createFrozenLoan(uint256 skipPeriodsBeforeFreezing) private returns (uint256) {
        uint256 loanId = createActiveLoan(skipPeriodsBeforeFreezing);

        vm.prank(LENDER_1);
        market.freeze(loanId);

        return loanId;
    }

    function createRepaidLoan(uint256 skipPeriodsBeforeRepayment) private returns (uint256) {
        uint256 loanId = createActiveLoan(skipPeriodsBeforeRepayment);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance != 0, true);
        token.mint(BORROWER_1, outstandingBalance);

        vm.startPrank(BORROWER_1);
        token.approve(address(market), outstandingBalance);
        market.repayLoan(loanId, outstandingBalance);
        vm.stopPrank();

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance == 0, true);

        return loanId;
    }

    function createDefaultedLoan(uint256 skipPeriodsAfterDefault) private returns (uint256) {
        uint256 loanId = createActiveLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);

        skip(loan.periodInSeconds * loan.durationInPeriods);
        skip(loan.periodInSeconds * skipPeriodsAfterDefault);

        return loanId;
    }

    function initBorrowerConfig(uint256 blockTimestamp)
        private
        pure
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: (blockTimestamp + BORROWER_CONFIG_DURATION).toUint32(),
            minBorrowAmount: BORROWER_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: BORROWER_CONFIG_MAX_BORROW_AMOUNT,
            minDurationInPeriods: BORROWER_CONFIG_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: BORROWER_CONFIG_MAX_DURATION_IN_PERIODS,
            interestRatePrimary: BORROWER_CONFIG_INTEREST_RATE_PRIMARY,
            interestRateSecondary: BORROWER_CONFIG_INTEREST_RATE_SECONDARY,
            addonFixedRate: BORROWER_CONFIG_ADDON_FIXED_RATE,
            addonPeriodRate: BORROWER_CONFIG_ADDON_PERIOD_RATE,
            interestFormula: BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND,
            borrowPolicy: BORROWER_CONFIG_BORROW_POLICY_DECREASE,
            autoRepayment: BORROWER_CONFIG_AUTOREPAYMENT,
            revocationPeriods: BORROWER_CONFIG_REVOCATION_PERIODS
        });
    }

    function initBorrowerConfigs(uint256 blockTimestamp)
        private
        pure
        returns (address[] memory, ICreditLineConfigurable.BorrowerConfig[] memory)
    {
        address[] memory borrowers = new address[](3);
        borrowers[0] = BORROWER_1;
        borrowers[1] = BORROWER_2;
        borrowers[2] = BORROWER_3;

        ICreditLineConfigurable.BorrowerConfig[] memory configs = new ICreditLineConfigurable.BorrowerConfig[](3);
        configs[0] = initBorrowerConfig(blockTimestamp);
        configs[1] = initBorrowerConfig(blockTimestamp);
        configs[2] = initBorrowerConfig(blockTimestamp);

        return (borrowers, configs);
    }

    function initCreditLineConfig() private pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            treasury: LOAN_TREASURY,
            periodInSeconds: CREDIT_LINE_CONFIG_PERIOD_IN_SECONDS,
            minDurationInPeriods: CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS,
            minBorrowAmount: CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT,
            minInterestRatePrimary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY,
            interestRateFactor: CREDIT_LINE_CONFIG_INTEREST_RATE_FACTOR,
            minAddonFixedRate: CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_RATE,
            maxAddonFixedRate: CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_RATE,
            minAddonPeriodRate: CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_RATE,
            maxAddonPeriodRate: CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_RATE,
            minRevocationPeriods: CREDIT_LINE_CONFIG_MIN_REVOCATION_PERIODS,
            maxRevocationPeriods: CREDIT_LINE_CONFIG_MAX_REVOCATION_PERIODS
        });
    }

    function initLoanTerms(address token_) internal pure returns (Loan.Terms memory) {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = initCreditLineConfig();
        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(0);
        return Loan.Terms({
            token: token_,
            treasury: address(0),
            periodInSeconds: creditLineConfig.periodInSeconds,
            durationInPeriods: DURATION_IN_PERIODS,
            interestRateFactor: creditLineConfig.interestRateFactor,
            interestRatePrimary: borrowerConfig.interestRatePrimary,
            interestRateSecondary: borrowerConfig.interestRateSecondary,
            interestFormula: borrowerConfig.interestFormula,
            autoRepayment: borrowerConfig.autoRepayment,
            addonAmount: ADDON_AMOUNT,
            revocationPeriods: borrowerConfig.revocationPeriods
        });
    }

    // -------------------------------------------- //
    //  Test `initialize` function                  //
    // -------------------------------------------- //

    function test_initialize() public {
        market = new LendingMarket();
        market.initialize("NAME", "SYMBOL");

        assertEq(market.name(), "NAME");
        assertEq(market.symbol(), "SYMBOL");
        assertEq(market.owner(), address(this));

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize("NEW_NAME", "NEW_SYMBOL");
    }

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

    function test_pause() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        market.pause();
        assertEq(market.paused(), true);
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        assertEq(market.paused(), false);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.pause();
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        market.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.pause();
    }

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

    function test_unpause() public {
        vm.startPrank(OWNER);
        assertEq(market.paused(), false);
        market.pause();
        assertEq(market.paused(), true);
        market.unpause();
        assertEq(market.paused(), false);
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        market.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.unpause();
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    // -------------------------------------------- //
    //  Test `setRegistry` function                 //
    // -------------------------------------------- //

    function test_setRegistry() public {
        assertEq(market.registry(), REGISTRY_1);

        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(market));
        emit MarketRegistryChanged(address(0), REGISTRY_1);
        market.setRegistry(address(0));
        assertEq(market.registry(), address(0));

        vm.expectEmit(true, true, true, true, address(market));
        emit MarketRegistryChanged(REGISTRY_2, address(0));
        market.setRegistry(REGISTRY_2);
        assertEq(market.registry(), REGISTRY_2);
    }

    function test_setRegistry_Revert_IfCallerNotOwner() public {
        assertEq(market.registry(), REGISTRY_1);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.setRegistry(REGISTRY_2);
    }

    function test_setRegistry_Revert_IfAlreadyConfigured() public {
        assertEq(market.registry(), REGISTRY_1);
        vm.prank(OWNER);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.setRegistry(REGISTRY_1);
    }

    // -------------------------------------------- //
    //  Test `registerCreditLine` function          //
    // -------------------------------------------- //

    function test_registerCreditLine_IfOwner() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineRegistered(LENDER_1, address(creditLine));
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_registerCreditLine_IfRegistry() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineRegistered(LENDER_1, address(creditLine));
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_registerCreditLine_Revert_IfOwner_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfRegistry_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(REGISTRY_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCallerNotRegistryOrOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    function test_registerCreditLine_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(address(0), address(creditLine));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerCreditLine(LENDER_1, address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        market.registerCreditLine(LENDER_1, address(creditLine));
    }

    // -------------------------------------------- //
    //  Test `registerLiquidityPool` function       //
    // -------------------------------------------- //

    function test_registerLiquidityPool_IfOwner() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolRegistered(LENDER_1, address(liquidityPool));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_registerLiquidityPool_IfRegistry() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolRegistered(LENDER_1, address(liquidityPool));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_registerLiquidityPool_Revert_IfOwner_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfRegistry_ContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(REGISTRY_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotRegistryOrOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(address(0), address(liquidityPool));
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.registerLiquidityPool(LENDER_1, address(0));
    }

    function test_registerLiquidityPool_Revert_IfLiquidityPoolIsAlreadyRegistered() public {
        vm.startPrank(OWNER);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
    }

    // -------------------------------------------- //
    //  Test `updateCreditLineLender`               //
    // -------------------------------------------- //

    function test_updateCreditLineLender() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));

        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineLenderUpdated(address(creditLine), LENDER_2, LENDER_1);
        market.updateCreditLineLender(address(creditLine), LENDER_2);

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_2);
    }

    function test_updateCreditLineLender_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.updateCreditLineLender(address(creditLine), LENDER_1);
    }

    function test_updateCreditLineLender_Revert_IfCreditLineIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.updateCreditLineLender(address(0), LENDER_1);
    }

    function test_updateCreditLineLender_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.updateCreditLineLender(address(creditLine), address(0));
    }

    function test_updateCreditLineLender_Revert_IfLenderAlreadyConfigured() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.updateCreditLineLender(address(creditLine), LENDER_1);
    }

    // -------------------------------------------- //
    //  Test `updateLiquidityPoolLender`            //
    // -------------------------------------------- //

    function test_updateLiquidityPoolLender() public {
        vm.startPrank(OWNER);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolLenderUpdated(address(liquidityPool), LENDER_2, LENDER_1);
        market.updateLiquidityPoolLender(address(liquidityPool), LENDER_2);

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_2);
    }

    function test_updateLiquidityPoolLender_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        market.updateLiquidityPoolLender(address(liquidityPool), LENDER_1);
    }

    function test_updateLiquidityPoolLender_Revert_IfLiquidityPoolIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.updateLiquidityPoolLender(address(0), LENDER_1);
    }

    function test_updateLiquidityPoolLender_Revert_IfLenderIsZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.updateLiquidityPoolLender(address(liquidityPool), address(0));
    }

    function test_updateLiquidityPoolLender_Revert_IfLenderAlreadyConfigured() public {
        vm.startPrank(OWNER);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.updateLiquidityPoolLender(address(liquidityPool), LENDER_1);
    }

    // -------------------------------------------- //
    //  Test `assignLiquidityPoolToCreditLine`      //
    // -------------------------------------------- //

    function test_assignLiquidityPoolToCreditLine() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));
        vm.stopPrank();

        assertEq(market.getLiquidityPoolByCreditLine(address(creditLine)), address(0));

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolAssignedToCreditLine(address(creditLine), address(liquidityPool), address(0));
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));

        assertEq(market.getLiquidityPoolByCreditLine(address(creditLine)), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfContractIsPaused() public {
        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfCreditLineIsZeroAddress() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.assignLiquidityPoolToCreditLine(address(0), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfLiquidityPoolIsZeroAddress() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(0));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfAlreadyAssigned() public {
        configureMarket();
        vm.prank(LENDER_1);
        vm.expectRevert(Error.NotImplemented.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), LIQUIDITY_POOL_1);
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfWrongCreditLineLender() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_2, address(liquidityPool));
        vm.stopPrank();

        vm.prank(LENDER_2);
        vm.expectRevert(Error.Unauthorized.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    function test_assignLiquidityPoolToCreditLine_Revert_IfWrongLiquidityPoolLender() public {
        vm.startPrank(OWNER);
        market.registerCreditLine(LENDER_1, address(creditLine));
        market.registerLiquidityPool(LENDER_2, address(liquidityPool));
        vm.stopPrank();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.Unauthorized.selector);
        market.assignLiquidityPoolToCreditLine(address(creditLine), address(liquidityPool));
    }

    // -------------------------------------------- //
    //  Test `takeLoan` function                    //
    // -------------------------------------------- //

    function test_takeLoan() public {
        configureMarket();
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();
        uint256 totalBorrowAmount = borrowAmount + terms.addonAmount;
        uint256 loanId = 0;

        token.mint(address(liquidityPool), borrowAmount);

        assertEq(token.balanceOf(address(liquidityPool)), borrowAmount);
        assertEq(token.balanceOf(BORROWER_1), 0);
        assertEq(market.totalSupply(), 0);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnBeforeLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanTakenCalled(loanId, address(creditLine));
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanTaken(loanId, BORROWER_1, totalBorrowAmount, terms.durationInPeriods);

        vm.prank(BORROWER_1);
        assertEq(market.takeLoan(address(creditLine), borrowAmount, terms.durationInPeriods), loanId);

        Loan.State memory loan = market.getLoanState(loanId);

        assertEq(token.balanceOf(BORROWER_1), borrowAmount);
        assertEq(token.balanceOf(address(liquidityPool)), 0);
        assertEq(market.ownerOf(loanId), LENDER_1);
        assertEq(market.totalSupply(), 1);

        assertEq(loan.token, terms.token);
        assertEq(loan.borrower, BORROWER_1);
        assertEq(loan.treasury, terms.treasury);
        assertEq(loan.startTimestamp, block.timestamp);
        assertEq(loan.trackedTimestamp, block.timestamp);
        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.initialBorrowAmount, totalBorrowAmount);
        assertEq(loan.trackedBorrowBalance, totalBorrowAmount);
        assertEq(loan.addonAmount, terms.addonAmount);
        assertEq(loan.autoRepayment, terms.autoRepayment);
        assertEq(loan.periodInSeconds, terms.periodInSeconds);
        assertEq(loan.durationInPeriods, terms.durationInPeriods);
        assertEq(loan.revocationPeriods, terms.revocationPeriods);
        assertEq(loan.interestRateFactor, terms.interestRateFactor);
        assertEq(loan.interestRatePrimary, terms.interestRatePrimary);
        assertEq(loan.interestRateSecondary, terms.interestRateSecondary);
        assertEq(uint256(loan.interestFormula), uint256(terms.interestFormula));
    }

    function test_takeLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();

        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoan(address(creditLine), borrowAmount, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfBorrowAmountIsZero() public {
        configureMarket();
        (, Loan.Terms memory terms) = mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(address(creditLine), 0, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfCreditLineIsZeroAddress() public {
        configureMarket();
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.takeLoan(address(0), borrowAmount, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfCreditLineIsNotRegistered() public {
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfLiquidityPoolIsNotRegistered() public {
        (uint256 borrowAmount, Loan.Terms memory terms) = mockLoanTerms();

        vm.prank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.takeLoan(address(creditLine), borrowAmount, terms.durationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `repayLoan` function                  //
    // -------------------------------------------- //

    function repayLoan(uint256 loanId, bool autoRepaymnet) private {
        Loan.State memory loan = market.getLoanState(loanId);

        assertEq(market.ownerOf(loanId), LENDER_1);
        assertEq(loan.trackedBorrowBalance >= 2, true);

        vm.prank(BORROWER_1);
        token.approve(address(market), type(uint256).max);

        // Repayment mode
        if (autoRepaymnet) {
            vm.startPrank(address(liquidityPool));
        } else {
            vm.startPrank(BORROWER_1);
        }

        // Partial repayment

        skip(loan.periodInSeconds * 2);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        uint256 repayAmount = outstandingBalance / 2;
        outstandingBalance -= repayAmount;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, BORROWER_1, BORROWER_1, repayAmount, outstandingBalance);
        market.repayLoan(loanId, repayAmount);

        uint256 newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, outstandingBalance);
        assertEq(market.ownerOf(loanId), LENDER_1);

        // Full repayment

        skip(loan.periodInSeconds * 3);

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, outstandingBalance);

        newOutstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(newOutstandingBalance, 0);
        assertEq(market.ownerOf(loanId), BORROWER_1);
    }

    function test_repayLoan_IfLoanIsActive() public {
        configureMarket();
        repayLoan(createActiveLoan(1), false);
    }

    function test_repayLoan_IfLoanIsFrozen() public {
        configureMarket();
        repayLoan(createFrozenLoan(1), false);
    }

    function test_repayLoan_IfLoanIsDefaulted() public {
        configureMarket();
        repayLoan(createDefaultedLoan(1), false);
    }

    function test_repayLoan_IfLoanIsActive_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createActiveLoan(1), true);
    }

    function test_repayLoan_IfLoanIsFrozen_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createFrozenLoan(1), true);
    }

    function test_repayLoan_IfLoanIsDefaulted_AutoRepayment() public {
        configureMarket();
        overrideAutoRepayment = true;
        canOverrideAutoRepayment = true;
        repayLoan(createDefaultedLoan(1), true);
    }

    function test_repayLoan_IRepaymentAmountIsUint256Max() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.startPrank(BORROWER_1);

        token.approve(address(market), type(uint256).max);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance != 0, true);

        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, BORROWER_1, BORROWER_1, outstandingBalance, 0);
        market.repayLoan(loanId, type(uint256).max);

        outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        assertEq(outstandingBalance, 0);
    }

    function test_repayLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(BORROWER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.repayLoan(loanId, loan.trackedBorrowBalance);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        configureMarket();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(LOAN_ID_NONEXISTENT, 1);
    }

    function test_repayLoan_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, 1);
    }

    function test_repayLoan_Revert_IfRepayAmountIsZero() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, 0);
    }

    function test_repayLoan_Revert_IfAutoRepaymentIsNotAllowed() public {
        configureMarket();

        canOverrideAutoRepayment = true;
        overrideAutoRepayment = false;

        uint256 loanId = createActiveLoan(1);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1));

        vm.prank(address(liquidityPool));
        vm.expectRevert(LendingMarket.AutoRepaymentNotAllowed.selector);
        market.repayLoan(loanId, outstandingBalance);
    }

    function test_repayLoan_Revert_IfRepayAmountIsGreaterThanBorrowAmount() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER_1, outstandingBalance - token.balanceOf(BORROWER_1) + 1);

        vm.prank(BORROWER_1);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, outstandingBalance + 1);
    }

    // -------------------------------------------- //
    //  Test `revokeLoan` function                  //
    // -------------------------------------------- //

    function test_revokeLoan() public {
        configureMarket();

        uint256 loanId = createActiveLoan(0);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 borrowerBalance = token.balanceOf(loan.borrower);
        uint256 treasuryBalance = token.balanceOf(loan.treasury);
        uint256 borrowAmount = loan.initialBorrowAmount - loan.addonAmount;

        skip(loan.periodInSeconds * (loan.revocationPeriods - 1));

        vm.prank(loan.borrower);
        token.approve(address(market), borrowAmount);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnBeforeLoanRevocationCalled(loanId);
        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanRevocationCalled(loanId);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRevoked(loanId);

        vm.prank(loan.borrower);
        market.revokeLoan(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.trackedBorrowBalance, 0);
        assertEq(token.balanceOf(loan.borrower), borrowerBalance - borrowAmount);
        assertEq(token.balanceOf(address(loan.treasury)), treasuryBalance + borrowAmount);
    }

    function test_revokeLoan_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(loan.borrower);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.revokeLoan(loanId);
    }

    function test_revokeLoan_Revert_IfLoanNotExist() public {
        configureMarket();

        vm.prank(BORROWER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.revokeLoan(LOAN_ID_NONEXISTENT);
    }

    function test_revokeLoan_Revert_IfRevocationIsProhibited() public {
        configureMarket();

        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.trackedTimestamp, loan.startTimestamp);

        skip(1);

        vm.startPrank(loan.borrower);
        token.approve(address(market), 1);
        market.repayLoan(loanId, 1);

        vm.expectRevert(LendingMarket.RevocationIsProhibited.selector);
        market.revokeLoan(loanId);
    }

    function test_revokeLoan_Revert_IfRevocationPeriodHasPassed() public {
        configureMarket();

        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.trackedTimestamp, loan.startTimestamp);

        skip(loan.periodInSeconds * loan.revocationPeriods);

        vm.prank(loan.borrower);
        vm.expectRevert(LendingMarket.RevocationPeriodHasPassed.selector);
        market.revokeLoan(loanId);
    }

    // -------------------------------------------- //
    //  Test `freeze` function                      //
    // -------------------------------------------- //

    function test_freeze(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp, 0);

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanFrozen(loanId);
        market.freeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp, block.timestamp);
    }

    function test_freeze_IfLender() public {
        test_freeze(LENDER_1);
    }

    function test_freeze_IfLenderAlias() public {
        test_freeze(LENDER_1_ALIAS);
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.freeze(LOAN_ID_NONEXISTENT);
    }

    function test_freeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        market.freeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `unfreeze` function                    //
    // -------------------------------------------- //

    function test_unfreeze(address caller) private {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);

        Loan.State memory loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp != 0, true);

        vm.prank(caller);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp, 0);
    }

    function test_unfreeze_IfLender() public {
        test_unfreeze(LENDER_1);
    }

    function test_unfreeze_IfLenderAlias() public {
        test_unfreeze(LENDER_1_ALIAS);
    }

    function test_unfreeze_IfSamePeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;
        // uint256 currentTimestamp = preview.period * loan.durationInPeriods;

        // assertEq(loan.freezeTimestamp, currentTimestamp);
        // assertEq(loan.trackedTimestamp, currentTimestamp);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanUnfrozen(loanId);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        preview = market.getLoanPreview(loanId, 0);

        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.trackedTimestamp, block.timestamp);
        assertEq(loan.durationInPeriods, oldDurationInPeriods);
        assertEq(preview.outstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_IfDifferentPeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(0);

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;

        assertEq(loan.freezeTimestamp, block.timestamp);
        assertEq(loan.trackedTimestamp, block.timestamp);

        uint256 skipPeriods = 2;
        skip(loan.periodInSeconds * skipPeriods);

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanUnfrozen(loanId);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        preview = market.getLoanPreview(loanId, 0);

        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.trackedTimestamp, block.timestamp);
        assertEq(loan.durationInPeriods, oldDurationInPeriods + skipPeriods);
        assertEq(preview.outstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.unfreeze(LOAN_ID_NONEXISTENT);
    }

    function test_unfreeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        market.unfreeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `updateLoanDuration` function          //
    // -------------------------------------------- //

    function test_updateLoanDuration(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanDurationUpdated(loanId, newDurationInPeriods, loan.durationInPeriods);
        market.updateLoanDuration(loanId, newDurationInPeriods);

        loan = market.getLoanState(loanId);
        assertEq(loan.durationInPeriods, newDurationInPeriods);
    }

    function test_updateLoanDuration_IfLender() public {
        test_updateLoanDuration(LENDER_1);
    }

    function test_updateLoanDuration_IfLenderAlias() public {
        test_updateLoanDuration(LENDER_1_ALIAS);
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.prank(OWNER);
        market.pause();

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        uint256 newDurationInPeriods = 2;
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanDuration(LOAN_ID_NONEXISTENT, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfRepaidLoan() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfSameLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfDecreasedLoanDuration() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRatePrimary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRatePrimary(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRatePrimary = loan.interestRatePrimary;
        uint256 newInterestRatePrimary = oldInterestRatePrimary - 1;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRatePrimaryUpdated(loanId, newInterestRatePrimary, oldInterestRatePrimary);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRatePrimary, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_IfLender() public {
        test_updateLoanInterestRatePrimary(LENDER_1);
    }

    function test_updateLoanInterestRatePrimary_IfLenderAlias() public {
        test_updateLoanInterestRatePrimary(LENDER_1_ALIAS);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRatePrimary(LOAN_ID_NONEXISTENT, 1);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfIncreasedInterestRate() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRateSecondary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRateSecondary(address caller) private {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRateSecondary = loan.interestRateSecondary;
        uint256 newInterestRateSecondary = oldInterestRateSecondary - 1;

        vm.prank(caller);
        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRateSecondaryUpdated(loanId, newInterestRateSecondary, oldInterestRateSecondary);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRateSecondary, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_IfLender() public {
        test_updateLoanInterestRateSecondary(LENDER_1);
    }

    function test_updateLoanInterestRateSecondary_IfLenderAlias() public {
        test_updateLoanInterestRateSecondary(LENDER_1_ALIAS);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRateSecondary(LOAN_ID_NONEXISTENT, 1);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoadIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfIncreasedInterestRate() public {
        configureMarket();
        uint256 loanId = createActiveLoan(1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    // -------------------------------------------- //
    //  Test `configureAlias` function              //
    // -------------------------------------------- //

    function test_configureAlias() public {
        configureMarket();

        vm.startPrank(LENDER_1);

        vm.expectEmit(true, true, true, true, address(market));
        emit LenderAliasConfigured(LENDER_1, LENDER_1_ALIAS, false);
        market.configureAlias(LENDER_1_ALIAS, false);
        assertEq(market.hasAlias(LENDER_1, LENDER_1_ALIAS), false);

        vm.expectEmit(true, true, true, true, address(market));
        emit LenderAliasConfigured(LENDER_1, LENDER_1_ALIAS, true);
        market.configureAlias(LENDER_1_ALIAS, true);
        assertEq(market.hasAlias(LENDER_1, LENDER_1_ALIAS), true);
    }

    function test_configureAlias_Revert_IfContractIsPaused() public {
        configureMarket();

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.configureAlias(LENDER_1_ALIAS, true);
    }

    function test_configureAlias_Revert_IfAliasIsZeroAddress() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.configureAlias(address(0), true);
    }

    function test_configureAlias_Revert_IfAliasIsAlreadyConfigured() public {
        configureMarket();

        vm.prank(LENDER_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.configureAlias(LENDER_1_ALIAS, true);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getCreditLineLender() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(REGISTRY_1);
        market.registerCreditLine(LENDER_1, address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER_1);
    }

    function test_getLiquidityPoolLender() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(REGISTRY_1);
        market.registerLiquidityPool(LENDER_1, address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER_1);
    }

    function test_calculatePeriodIndex() public {
        uint256 timestamp = 10 ** 6 - 1;
        uint256 periodInSeconds = 1 seconds;
        uint256 expectedCurrentPeriod = timestamp / periodInSeconds;

        assertEq(market.calculatePeriodIndex(timestamp, periodInSeconds), expectedCurrentPeriod);

        periodInSeconds = 19 seconds;
        for (uint256 i = 0; i <= periodInSeconds; ++i) {
            expectedCurrentPeriod = timestamp / periodInSeconds;
            assertEq(market.calculatePeriodIndex(timestamp, periodInSeconds), expectedCurrentPeriod);
            timestamp += 1;
        }
    }

    // -------------------------------------------- //
    //  ERC165 support                              //
    // -------------------------------------------- //

    function test_supportsInterface() public {
        assertEq(market.supportsInterface(0x0), false);
        assertEq(market.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(market.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(market.supportsInterface(0x5b5e139f), true); // ERC721Metadata
        assertEq(market.supportsInterface(0x780e9d63), true); // ERC721Enumerable
    }
}

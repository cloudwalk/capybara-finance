// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Round } from "src/common/libraries/Round.sol";
import { SafeCast } from "src/common/libraries/SafeCast.sol";
import { Constants } from "src/common/libraries/Constants.sol";

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

    event OnBeforeLoanTakenCalled(uint256 indexed loanId);

    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnAfterLoanRevocationCalled(uint256 indexed loanId);

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

    event LoanFrozen(uint256 indexed loanId);
    event LoanUnfrozen(uint256 indexed loanId);
    event LoanRevoked(uint256 indexed loanId);

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
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant BORROWER = address(bytes20(keccak256("borrower")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));
    address private constant DEPLOYER = address(bytes20(keccak256("deployer")));

    address private constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address private constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address private constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address private constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    address private constant LENDER_ALIAS = address(bytes20(keccak256("lender_alias")));

    uint32 private constant PROGRAM_ID = 1;
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint64 private constant ADDON_AMOUNT = 100 * Constants.ACCURACY_FACTOR;
    uint64 private constant BORROW_AMOUNT = 100 * Constants.ACCURACY_FACTOR;
    uint32 private constant DURATION_IN_PERIODS = 30;
    uint256 private constant LOAN_ID_NONEXISTENT = 111_111_111;
    uint256 private constant INIT_BLOCK_TIMESTAMP = 999_999_999;
    uint256 private constant NEGAVIVE_TIME_SHIFT = 3 hours;

    uint64 private constant CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT = 400 * Constants.ACCURACY_FACTOR;
    uint64 private constant CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT = 900 * Constants.ACCURACY_FACTOR;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY = 3;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY = 7;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY = 4;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY = 8;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS = 50;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS = 200;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_RATE = 10;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_RATE = 50;
    uint32 private constant CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_RATE = 10;
    uint32 private constant CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_RATE = 50;

    uint32 private constant BORROWER_CONFIG_ADDON_FIXED_RATE = 15;
    uint32 private constant BORROWER_CONFIG_ADDON_PERIOD_RATE = 20;
    uint32 private constant BORROWER_CONFIG_MIN_DURATION_IN_PERIODS = 25;
    uint32 private constant BORROWER_CONFIG_MAX_DURATION_IN_PERIODS = 35;
    uint32 private constant BORROWER_CONFIG_DURATION = 1000;
    uint64 private constant BORROWER_CONFIG_MIN_BORROW_AMOUNT = 500;
    uint64 private constant BORROWER_CONFIG_MAX_BORROW_AMOUNT = 800;
    uint32 private constant BORROWER_CONFIG_INTEREST_RATE_PRIMARY = 5;
    uint32 private constant BORROWER_CONFIG_INTEREST_RATE_SECONDARY = 6;
    ICreditLineConfigurable.BorrowPolicy private constant BORROWER_CONFIG_BORROW_POLICY_DECREASE =
        ICreditLineConfigurable.BorrowPolicy.Reset;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        vm.startPrank(DEPLOYER);

        token = new ERC20Mock();
        creditLine = new CreditLineMock();
        liquidityPool = new LiquidityPoolMock();
        market = new LendingMarket();
        market.initialize(OWNER);

        skip(INIT_BLOCK_TIMESTAMP);

        vm.stopPrank();
    }

    function configureMarket() private {
        vm.startPrank(LENDER);
        market.registerCreditLine(address(creditLine));
        market.registerLiquidityPool(address(liquidityPool));
        market.createProgram(address(creditLine), address(liquidityPool));
        vm.stopPrank();

        vm.prank(BORROWER);
        token.approve(address(market), type(uint256).max);

        vm.prank(address(liquidityPool));
        token.approve(address(market), type(uint256).max);
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
            borrowPolicy: BORROWER_CONFIG_BORROW_POLICY_DECREASE
        });
    }

    function initBorrowerConfigs(uint256 blockTimestamp)
        private
        pure
        returns (address[] memory, ICreditLineConfigurable.BorrowerConfig[] memory)
    {
        address[] memory borrowers = new address[](3);
        borrowers[0] = BORROWER;
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
            minDurationInPeriods: CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS,
            minBorrowAmount: CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT,
            minInterestRatePrimary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY,
            minAddonFixedRate: CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_RATE,
            maxAddonFixedRate: CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_RATE,
            minAddonPeriodRate: CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_RATE,
            maxAddonPeriodRate: CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_RATE
        });
    }

    function mockLoanTerms(address borrower, uint256 borrowAmount) private returns (Loan.Terms memory) {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = initCreditLineConfig();
        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(0);

        Loan.Terms memory terms = Loan.Terms({
            token: address(token),
            durationInPeriods: DURATION_IN_PERIODS,
            interestRatePrimary: borrowerConfig.interestRatePrimary,
            interestRateSecondary: borrowerConfig.interestRateSecondary,
            addonAmount: ADDON_AMOUNT
        });

        creditLine.mockLoanTerms(borrower, borrowAmount, terms);

        return terms;
    }

    function createLoan(address borrower, uint256 borrowAmount) private returns (uint256) {
        Loan.Terms memory terms = mockLoanTerms(borrower, borrowAmount);
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        vm.prank(borrower);
        uint256 loanId = market.takeLoan(PROGRAM_ID, borrowAmount, terms.durationInPeriods);

        return loanId;
    }

    function repayLoan(uint256 loanId) private {
        Loan.State memory loan = market.getLoanState(loanId);
        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(loan.borrower, outstandingBalance);

        vm.prank(loan.borrower);
        market.repayLoan(loanId, outstandingBalance);
    }

    function defaultLoan(uint256 loanId) private {
        Loan.State memory loan = market.getLoanState(loanId);
        skip(Constants.PERIOD_IN_SECONDS * loan.durationInPeriods);
    }

    function freezeLoan(address lender, uint256 loanId) private {
        vm.prank(lender);
        market.freeze(loanId);
    }

    function unfreezeLoan(address lender, uint256 loanId) private {
        vm.prank(lender);
        market.unfreeze(loanId);
    }

    function createActiveLoan(
        address borrower,
        uint256 borrowAmount,
        uint256 skipPeriods
    ) private returns (uint256) {
        Loan.Terms memory terms = mockLoanTerms(borrower, borrowAmount);
        token.mint(address(liquidityPool), borrowAmount + terms.addonAmount);

        vm.prank(borrower);
        uint256 loanId = market.takeLoan(PROGRAM_ID, borrowAmount, terms.durationInPeriods);

        skip(Constants.PERIOD_IN_SECONDS * skipPeriods);

        return loanId;
    }

    function createFrozenLoan(
        address lender,
        address borrower,
        uint256 borrowAmount,
        uint256 skipPeriods
    ) private returns (uint256) {
        uint256 loanId = createActiveLoan(borrower, borrowAmount, skipPeriods);

        vm.prank(lender);
        market.freeze(loanId);

        return loanId;
    }

    function createDefaultedLoan(
        address borrower,
        uint256 borrowAmount,
        uint256 skipPeriods
    ) private returns (uint256) {
        uint256 loanId = createActiveLoan(borrower, borrowAmount, 0);
        Loan.State memory loan = market.getLoanState(loanId);

        skip(Constants.PERIOD_IN_SECONDS * loan.durationInPeriods);
        skip(Constants.PERIOD_IN_SECONDS * skipPeriods);

        return loanId;
    }

    function createRepaidLoan(
        address borrower,
        uint256 borrowAmount,
        uint256 skipPeriods
    ) private returns (uint256) {
        uint256 loanId = createActiveLoan(borrower, borrowAmount, skipPeriods);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(borrower, outstandingBalance);

        vm.prank(borrower);
        market.repayLoan(loanId, outstandingBalance);

        return loanId;
    }

    function blockTimestamp() private view returns (uint256) {
        return block.timestamp - NEGAVIVE_TIME_SHIFT;
    }

    // -------------------------------------------- //
    //  Test `initialize` function                  //
    // -------------------------------------------- //

    function test_initialize() public {
        vm.startPrank(DEPLOYER);

        market = new LendingMarket();
        assertEq(market.hasRole(OWNER_ROLE, OWNER), false);

        market.initialize(OWNER);

        assertEq(market.hasRole(OWNER_ROLE, OWNER), true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize(OWNER);
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        market.unpause();
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(market.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    // -------------------------------------------- //
    //  Test `takeLoan` function                    //
    // -------------------------------------------- //

    struct TakeLoanData {
        Loan.Terms terms;
        uint256 loanId;
        uint256 borrowerBalanceBefore;
        uint256 liquidityPoolBalanceBefore;
    }

    function prepareLoanExpectations() private returns (TakeLoanData memory) {
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);
        uint256 totalBorrowAmount = BORROW_AMOUNT + terms.addonAmount;
        uint256 loanId = 0;

        token.mint(address(liquidityPool), BORROW_AMOUNT);

        uint256 borrowerBalance = token.balanceOf(BORROWER);
        uint256 liquidityPoolBalance = token.balanceOf(address(liquidityPool));

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnBeforeLoanTakenCalled(loanId);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnBeforeLoanTakenCalled(loanId);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanTaken(loanId, BORROWER, totalBorrowAmount, terms.durationInPeriods);

        assertEq(market.loanCounter(), 0); // number of loans taken

        return TakeLoanData({
            terms: terms,
            loanId: loanId,
            borrowerBalanceBefore: borrowerBalance,
            liquidityPoolBalanceBefore: liquidityPoolBalance
        });
    }

    function compareLoanState(TakeLoanData memory takeLoanData) private {
        Loan.Terms memory terms = takeLoanData.terms;
        uint256 totalBorrowAmount = BORROW_AMOUNT + terms.addonAmount;

        assertEq(market.loanCounter(), 1); // number of loans taken

        Loan.State memory loan = market.getLoanState(takeLoanData.loanId);

        assertEq(token.balanceOf(BORROWER), takeLoanData.borrowerBalanceBefore + BORROW_AMOUNT);
        assertEq(token.balanceOf(address(liquidityPool)), takeLoanData.liquidityPoolBalanceBefore - BORROW_AMOUNT);

        assertEq(loan.token, terms.token);
        assertEq(loan.borrower, BORROWER);
        assertEq(loan.programId, PROGRAM_ID);
        assertEq(loan.startTimestamp, blockTimestamp());
        assertEq(loan.trackedTimestamp, blockTimestamp());
        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.borrowAmount, BORROW_AMOUNT);
        assertEq(loan.trackedBalance, totalBorrowAmount);
        assertEq(loan.repaidAmount, 0);
        assertEq(loan.addonAmount, terms.addonAmount);
        assertEq(loan.durationInPeriods, terms.durationInPeriods);
        assertEq(loan.interestRatePrimary, terms.interestRatePrimary);
        assertEq(loan.interestRateSecondary, terms.interestRateSecondary);
    }

    function test_takeLoan() public {
        configureMarket();
        TakeLoanData memory takeLoanData = prepareLoanExpectations();
        vm.prank(BORROWER);
        assertEq(market.takeLoan(PROGRAM_ID, BORROW_AMOUNT, takeLoanData.terms.durationInPeriods), takeLoanData.loanId);
        compareLoanState(takeLoanData);
    }

    function test_takeLoan_Revert_IfContractIsPaused() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoan(PROGRAM_ID, BORROW_AMOUNT, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfBorrowAmountIsZero() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(PROGRAM_ID, 0, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfProgramIdIsZero() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.ProgramNotExist.selector);
        market.takeLoan(0, BORROW_AMOUNT, terms.durationInPeriods);
    }

    function test_takeLoan_Revert_IfMarketIsNotConfigured() public {
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.CreditLineLenderNotConfigured.selector);
        market.takeLoan(PROGRAM_ID, BORROW_AMOUNT, terms.durationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `takeLoanFor` function                 //
    // -------------------------------------------- //

    function test_takeLoanFor_ifCalledByLenderAlias() public {
        configureMarket();
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        TakeLoanData memory takeLoanData = prepareLoanExpectations();

        vm.prank(LENDER_ALIAS);
        assertEq(market.takeLoanFor(
            BORROWER,
            PROGRAM_ID,
            BORROW_AMOUNT,
            takeLoanData.terms.addonAmount,
            takeLoanData.terms.durationInPeriods
        ), takeLoanData.loanId);

        compareLoanState(takeLoanData);
    }

    function test_takeLoanFor_ifCalledByLender() public {
        configureMarket();
        TakeLoanData memory takeLoanData = prepareLoanExpectations();

        vm.prank(LENDER);
        assertEq(market.takeLoanFor(
            BORROWER,
            PROGRAM_ID,
            BORROW_AMOUNT,
            takeLoanData.terms.addonAmount,
            takeLoanData.terms.durationInPeriods
        ), takeLoanData.loanId);

        compareLoanState(takeLoanData);
    }

    function test_takeLoanFor_Revert_IfContractIsPaused() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.takeLoanFor(BORROWER, PROGRAM_ID, BORROW_AMOUNT, terms.addonAmount, terms.durationInPeriods);
    }

    function test_takeLoanFor_Revert_IfBorrowerIsZero() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);
        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.takeLoanFor(address(0), PROGRAM_ID, BORROW_AMOUNT, terms.addonAmount, terms.durationInPeriods);
    }

    function test_takeLoanFor_Revert_IfBorrowAmountIsZero() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoanFor(BORROWER, PROGRAM_ID, 0, terms.addonAmount, terms.durationInPeriods);
    }

    function test_takeLoanFor_Revert_IfUnauthorized() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(DEPLOYER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.takeLoanFor(BORROWER, PROGRAM_ID, BORROW_AMOUNT, terms.addonAmount, terms.durationInPeriods);
    }

    function test_takeLoanFor_Revert_IfProgramIdIsZero() public {
        configureMarket();
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);
        vm.prank(LENDER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.takeLoanFor(BORROWER, 0, BORROW_AMOUNT, terms.addonAmount, terms.durationInPeriods);
    }

    function test_takeLoanFor_Revert_IfMarketIsNotConfigured() public {
        Loan.Terms memory terms = mockLoanTerms(BORROWER, BORROW_AMOUNT);

        vm.prank(LENDER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.takeLoanFor(BORROWER, PROGRAM_ID, BORROW_AMOUNT, terms.addonAmount, terms.durationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `repayLoan` function                   //
    // -------------------------------------------- //

    function repayLoan(
        uint256 loanId,
        bool autoRepayment,
        uint256 skipPeriodsBeforePartialRepayment,
        uint256 skipPeriodsFullRepayment
    ) private {
        Loan.State memory loan = market.getLoanState(loanId);

        if (!autoRepayment) {
            vm.startPrank(loan.borrower);
        } else {
            vm.startPrank(market.getProgramLender(loan.programId));
        }

        // Partial repayment

        skip(Constants.PERIOD_IN_SECONDS * skipPeriodsBeforePartialRepayment);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        uint256 partialRepayAmount = outstandingBalance / 2;
        outstandingBalance -= partialRepayAmount;

        token.mint(loan.borrower, partialRepayAmount);

        address liquidityPool = market.getProgramLiquidityPool(loan.programId);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanPaymentCalled(loanId, partialRepayAmount);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnAfterLoanPaymentCalled(loanId, partialRepayAmount);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, loan.borrower, loan.borrower, partialRepayAmount, outstandingBalance);

        market.repayLoan(loanId, partialRepayAmount);

        loan = market.getLoanState(loanId);
        assertEq(loan.repaidAmount, partialRepayAmount);
        assertEq(market.getLoanPreview(loanId, 0).outstandingBalance, outstandingBalance);

        // Full repayment

        skip(Constants.PERIOD_IN_SECONDS * skipPeriodsFullRepayment);

        uint256 fullRepayAmount = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(loan.borrower, fullRepayAmount);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanPaymentCalled(loanId, fullRepayAmount);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnAfterLoanPaymentCalled(loanId, fullRepayAmount);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, loan.borrower, loan.borrower, fullRepayAmount, 0);

        market.repayLoan(loanId, fullRepayAmount);

        loan = market.getLoanState(loanId);
        assertEq(loan.repaidAmount, partialRepayAmount + fullRepayAmount);
        assertEq(market.getLoanPreview(loanId, 0).outstandingBalance, 0);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsActive() public {
        configureMarket();

        bool autoRepayment = false;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsFrozen() public {
        configureMarket();

        bool autoRepayment = false;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        freezeLoan(LENDER, loanId);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsDefaulted() public {
        configureMarket();

        bool autoRepayment = false;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        defaultLoan(loanId);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsActive_AutoRepayment() public {
        configureMarket();

        bool autoRepayment = true;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsFrozen_AutoRepayment() public {
        configureMarket();

        bool autoRepayment = true;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        freezeLoan(LENDER, loanId);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_CanBeRepaid_IfLoanIsDefaulted_AutoRepayment() public {
        configureMarket();
        bool autoRepayment = true;
        uint256 skipPeriodsBeforePartialRepayment = 5;
        uint256 skipPeriodsFullRepayment = 10;

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        defaultLoan(loanId);

        repayLoan(loanId, autoRepayment, skipPeriodsBeforePartialRepayment, skipPeriodsFullRepayment);
    }

    function test_repayLoan_IfRepaymentAmountIsUint256Max() public {
        configureMarket();

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);

        uint256 outstandingBalance = market.getLoanPreview(loanId, 0).outstandingBalance;
        token.mint(BORROWER, outstandingBalance);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(loanId, BORROWER, BORROWER, outstandingBalance, 0);

        vm.prank(BORROWER);
        market.repayLoan(loanId, type(uint256).max);

        assertEq(market.getLoanPreview(loanId, 0).outstandingBalance, 0);
    }

    function test_repayLoan_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        uint256 repayAmount = market.getLoanPreview(loanId, 0).outstandingBalance;

        vm.prank(OWNER);
        market.pause();

        vm.prank(BORROWER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfLoanNotExist() public {
        configureMarket();

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        uint256 repayAmount = market.getLoanPreview(loanId, 0).outstandingBalance;
        uint256 nonExistentLoanId = loanId + 1;

        vm.prank(BORROWER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(nonExistentLoanId, repayAmount);
    }

    function test_repayLoan_Revert_IfBorrowerAndLoanIsRepaid() public {
        configureMarket();

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        repayLoan(loanId);

        Loan.State memory loan = market.getLoanState(loanId);
        uint256 repayAmount = market.getLoanPreview(loanId, 0).outstandingBalance;

        vm.prank(loan.borrower);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfBorrowerAndRepayAmountIsZero() public {
        configureMarket();
        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        uint256 repayAmount = 0;

        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfBorrowerAndInvalidRepayAmount() public {
        configureMarket();
        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);
        uint256 repayAmount = preview.outstandingBalance * 2;

        vm.prank(BORROWER);
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfLenderAndLoanIsRepaid() public {
        configureMarket();

        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);
        repayLoan(loanId);

        Loan.State memory loan = market.getLoanState(loanId);
        uint256 repayAmount = market.getLoanPreview(loanId, 0).outstandingBalance;


        vm.prank(market.getProgramLender(loan.programId));
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfLenderAndRepayAmountIsZero() public {
        configureMarket();
        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);

        Loan.State memory loan = market.getLoanState(loanId);
        uint256 repayAmount = 0;

        vm.prank(market.getProgramLender(loan.programId));
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, repayAmount);
    }

    function test_repayLoan_Revert_IfLenderAndInvalidRepayAmount() public {
        configureMarket();
        uint256 loanId = createLoan(BORROWER, BORROW_AMOUNT);

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);
        uint256 repayAmount = preview.outstandingBalance * 2;

        vm.prank(market.getProgramLender(loan.programId));
        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(loanId, repayAmount);
    }

    // -------------------------------------------- //
    //  Test `revokeLoan` function                  //
    // -------------------------------------------- //

    function revokeLoanIfRepaidAmountZero(address caller) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        Loan.State memory loan = market.getLoanState(loanId);
        assertTrue(Constants.COOLDOWN_IN_PERIODS >= 2);

        skip(Constants.PERIOD_IN_SECONDS * (Constants.COOLDOWN_IN_PERIODS - 1));

        address liquidityPool = market.getProgramLiquidityPool(loan.programId);
        uint256 liquidityPoolBalance = token.balanceOf(liquidityPool);
        uint256 borrowerBalance = token.balanceOf(loan.borrower);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRevoked(loanId);

        vm.prank(caller);
        market.revokeLoan(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.trackedBalance, 0);
        assertEq(token.balanceOf(loan.borrower), borrowerBalance - loan.borrowAmount);
        assertEq(token.balanceOf(address(liquidityPool)), liquidityPoolBalance + loan.borrowAmount);
    }

    function revokeLoanIfRepaidAmountLessThanBorrowAmount(address caller) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        Loan.State memory loan = market.getLoanState(loanId);
        assertTrue(Constants.COOLDOWN_IN_PERIODS >= 2);

        skip(Constants.PERIOD_IN_SECONDS * (Constants.COOLDOWN_IN_PERIODS - 1));

        uint256 repayAmount = Round.roundUp(loan.borrowAmount / 3, Constants.ACCURACY_FACTOR);
        uint256 revokeAmount = loan.borrowAmount - repayAmount;

        token.mint(loan.borrower, repayAmount);
        vm.prank(loan.borrower);
        market.repayLoan(loanId, repayAmount);

        address liquidityPool = market.getProgramLiquidityPool(loan.programId);
        uint256 liquidityPoolBalance = token.balanceOf(liquidityPool);
        uint256 borrowerBalance = token.balanceOf(loan.borrower);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRevoked(loanId);

        vm.prank(caller);
        market.revokeLoan(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.trackedBalance, 0);
        assertEq(token.balanceOf(loan.borrower), borrowerBalance - revokeAmount);
        assertEq(token.balanceOf(address(liquidityPool)), liquidityPoolBalance + revokeAmount);
    }

    function revokeLoanIfRepaidAmountGreaterThanBorrowAmount(address caller) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        Loan.State memory loan = market.getLoanState(loanId);
        assertTrue(Constants.COOLDOWN_IN_PERIODS >= 2);
        assertTrue(loan.addonAmount >= 2);

        skip(Constants.PERIOD_IN_SECONDS * (Constants.COOLDOWN_IN_PERIODS - 1));

        uint256 repayAmount = loan.borrowAmount  +  loan.addonAmount / 2;
        uint256 revokeAmount = repayAmount - loan.borrowAmount;

        token.mint(loan.borrower, repayAmount);
        vm.prank(loan.borrower);
        market.repayLoan(loanId, repayAmount);

        address liquidityPool = market.getProgramLiquidityPool(loan.programId);
        uint256 liquidityPoolBalance = token.balanceOf(liquidityPool);
        uint256 borrowerBalance = token.balanceOf(loan.borrower);

        vm.expectEmit(true, true, true, true, address(liquidityPool));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit OnAfterLoanRevocationCalled(loanId);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRevoked(loanId);

        vm.prank(caller);
        market.revokeLoan(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.trackedBalance, 0);
        assertEq(token.balanceOf(loan.borrower), borrowerBalance + revokeAmount);
        assertEq(token.balanceOf(address(liquidityPool)), liquidityPoolBalance - revokeAmount);
    }

    function test_revokeLoan_Borrower_IfRepaidAmountZero() public {
        revokeLoanIfRepaidAmountZero(BORROWER);
    }

    function test_revokeLoan_Borrower_IfRepaidAmountLessThanBorrowAmount() public {
        revokeLoanIfRepaidAmountLessThanBorrowAmount(BORROWER);
    }

    function test_revokeLoan_Borrower_IfRepaidAmountGreaterThanBorrowAmount() public {
        revokeLoanIfRepaidAmountGreaterThanBorrowAmount(BORROWER);
    }

    function test_revokeLoan_Lender_IfRepaidAmountZero() public {
        revokeLoanIfRepaidAmountZero(LENDER);
    }

    function test_revokeLoan_Lender_IfRepaidAmountLessThanBorrowAmount() public {
        revokeLoanIfRepaidAmountLessThanBorrowAmount(LENDER);
    }

    function test_revokeLoan_Lender_IfRepaidAmountGreaterThanBorrowAmount() public {
        revokeLoanIfRepaidAmountGreaterThanBorrowAmount(LENDER);
    }

    function test_revokeLoan_LenderAlias_IfRepaidAmountZero() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        revokeLoanIfRepaidAmountZero(LENDER_ALIAS);
    }

    function test_revokeLoan_LenderAlias_IfRepaidAmountLessThanBorrowAmount() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        revokeLoanIfRepaidAmountLessThanBorrowAmount(LENDER_ALIAS);
    }

    function test_revokeLoan_LenderAlias_IfRepaidAmountGreaterThanBorrowAmount() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        revokeLoanIfRepaidAmountGreaterThanBorrowAmount(LENDER_ALIAS);
    }

    function test_revokeLoan_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);

        vm.startPrank(OWNER);
        market.pause();

        vm.startPrank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.revokeLoan(loanId);
    }

    function test_revokeLoan_Revert_IfLoanNotExist() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.revokeLoan(nonExistentLoanId);
    }

    function test_revokeLoan_Revert_IfUnauthorized() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.revokeLoan(loanId);
    }

    // -------------------------------------------- //
    //  Test `freeze` function                      //
    // -------------------------------------------- //

    function test_freeze(address lenderOrAlias) private {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);

        Loan.State memory loan = market.getLoanState(loanId);
        assertNotEq(loan.freezeTimestamp, blockTimestamp());
        assertEq(loan.freezeTimestamp, 0);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanFrozen(loanId);

        vm.prank(lenderOrAlias);
        market.freeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp, blockTimestamp());
    }

    function test_freeze_IfLender() public {
        test_freeze(LENDER);
    }

    function test_freeze_IfLenderAlias() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        test_freeze(LENDER_ALIAS);
    }

    function test_freeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanNotExist() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.freeze(nonExistentLoanId);
    }

    function test_freeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(BORROWER, BORROW_AMOUNT, 1);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.freeze(loanId);
    }

    function test_freeze_Revert_IfLoanIsFrozen() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 1);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyFrozen.selector);
        market.freeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `unfreeze` function                    //
    // -------------------------------------------- //

    function test_unfreeze(address lenderOrAlias) private {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 0);

        Loan.State memory loan = market.getLoanState(loanId);
        assertNotEq(loan.freezeTimestamp, 0);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanUnfrozen(loanId);

        vm.prank(lenderOrAlias);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        assertEq(loan.freezeTimestamp, 0);
    }

    function test_unfreeze_IfLender() public {
        test_unfreeze(LENDER);
    }

    function test_unfreeze_IfLenderAlias() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        test_unfreeze(LENDER_ALIAS);
    }

    function test_unfreeze_IfSamePeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 0);

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;

        vm.prank(LENDER);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        preview = market.getLoanPreview(loanId, 0);

        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.trackedTimestamp, blockTimestamp());
        assertEq(loan.durationInPeriods, oldDurationInPeriods);
        assertEq(preview.outstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_IfDifferentPeriod() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 0);

        Loan.State memory loan = market.getLoanState(loanId);
        Loan.Preview memory preview = market.getLoanPreview(loanId, 0);

        uint256 oldDurationInPeriods = loan.durationInPeriods;
        uint256 oldOutstandingBalance = preview.outstandingBalance;

        assertEq(loan.freezeTimestamp, blockTimestamp());
        assertEq(loan.trackedTimestamp, blockTimestamp());

        uint256 skipPeriods = 2;
        skip(Constants.PERIOD_IN_SECONDS * skipPeriods);

        vm.prank(LENDER);
        market.unfreeze(loanId);

        loan = market.getLoanState(loanId);
        preview = market.getLoanPreview(loanId, 0);

        assertEq(loan.freezeTimestamp, 0);
        assertEq(loan.trackedTimestamp, blockTimestamp());
        assertEq(loan.durationInPeriods, oldDurationInPeriods + skipPeriods);
        assertEq(preview.outstandingBalance, oldOutstandingBalance);
    }

    function test_unfreeze_Revert_IfContractIsPaused() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 1);

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfCallerNotLender() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 1);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotExist() public {
        configureMarket();
        uint256 loanId = createFrozenLoan(LENDER, BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.unfreeze(nonExistentLoanId);
    }

    function test_unfreeze_Revert_IfLoanIsRepaid() public {
        configureMarket();
        uint256 loanId = createRepaidLoan(BORROWER, BORROW_AMOUNT, 1);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.unfreeze(loanId);
    }

    function test_unfreeze_Revert_IfLoanNotFrozen() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotFrozen.selector);
        market.unfreeze(loanId);
    }

    // -------------------------------------------- //
    //  Test `updateLoanDuration` function          //
    // -------------------------------------------- //

    function test_updateLoanDuration(address lender) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanDurationUpdated(loanId, newDurationInPeriods, loan.durationInPeriods);

        vm.prank(lender);
        market.updateLoanDuration(loanId, newDurationInPeriods);

        loan = market.getLoanState(loanId);
        assertEq(loan.durationInPeriods, newDurationInPeriods);
    }

    function test_updateLoanDuration_IfLender() public {
        test_updateLoanDuration(LENDER);
    }

    function test_updateLoanDuration_IfLenderAlias() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        test_updateLoanDuration(LENDER_ALIAS);
    }

    function test_updateLoanDuration_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        vm.prank(OWNER);
        market.pause();

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLender() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfLoanNotExist() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;
        uint256 newDurationInPeriods = 10;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanDuration(nonExistentLoanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfRepaidLoan() public {
        configureMarket();

        uint256 loanId = createRepaidLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods + 2;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfSameLoanDuration() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    function test_updateLoanDuration_Revert_IfDecreasedLoanDuration() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newDurationInPeriods = loan.durationInPeriods - 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(loanId, newDurationInPeriods);
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRatePrimary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRatePrimary(address lender) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRatePrimary = loan.interestRatePrimary;
        uint256 newInterestRatePrimary = oldInterestRatePrimary - 1;

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRatePrimaryUpdated(loanId, newInterestRatePrimary, oldInterestRatePrimary);

        vm.prank(lender);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRatePrimary, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_IfLender() public {
        test_updateLoanInterestRatePrimary(LENDER);
    }

    function test_updateLoanInterestRatePrimary_IfLenderAlias() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        test_updateLoanInterestRatePrimary(LENDER_ALIAS);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLender() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoanNotExist() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;
        uint256 newInterestRatePrimary = 10;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRatePrimary(nonExistentLoanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfLoadIsRepaid() public {
        configureMarket();

        uint256 loanId = createRepaidLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary - 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfIncreasedInterestRate() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRatePrimary = loan.interestRatePrimary + 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(loanId, newInterestRatePrimary);
    }

    // -------------------------------------------- //
    //  Test `updateLoanInterestRateSecondary` function
    // -------------------------------------------- //

    function test_updateLoanInterestRateSecondary(address lender) private {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 oldInterestRateSecondary = loan.interestRateSecondary;
        uint256 newInterestRateSecondary = oldInterestRateSecondary - 1;

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRateSecondaryUpdated(loanId, newInterestRateSecondary, oldInterestRateSecondary);

        vm.prank(lender);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);

        loan = market.getLoanState(loanId);
        assertEq(loan.interestRateSecondary, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_IfLender() public {
        test_updateLoanInterestRateSecondary(LENDER);
    }

    function test_updateLoanInterestRateSecondary_IfLenderAlias() public {
        vm.prank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        test_updateLoanInterestRateSecondary(LENDER_ALIAS);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfContractIsPaused() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfCallerNotLender() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoanNotExist() public {
        configureMarket();
        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 0);
        uint256 nonExistentLoanId = loanId + 1;
        uint256 newInterestRateSecondary = 10;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.updateLoanInterestRateSecondary(nonExistentLoanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfLoadIsRepaid() public {
        configureMarket();

        uint256 loanId = createRepaidLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary - 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.LoanAlreadyRepaid.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfIncreasedInterestRate() public {
        configureMarket();

        uint256 loanId = createActiveLoan(BORROWER, BORROW_AMOUNT, 1);
        Loan.State memory loan = market.getLoanState(loanId);

        uint256 newInterestRateSecondary = loan.interestRateSecondary + 1;

        vm.prank(LENDER);
        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(loanId, newInterestRateSecondary);
    }

    // -------------------------------------------- //
    //  Test `configureAlias` function              //
    // -------------------------------------------- //

    function test_configureAlias() public {
        configureMarket();

        vm.startPrank(LENDER);

        vm.expectEmit(true, true, true, true, address(market));
        emit LenderAliasConfigured(LENDER, LENDER_ALIAS, true);
        market.configureAlias(LENDER_ALIAS, true);
        assertEq(market.hasAlias(LENDER, LENDER_ALIAS), true);

        vm.expectEmit(true, true, true, true, address(market));
        emit LenderAliasConfigured(LENDER, LENDER_ALIAS, false);
        market.configureAlias(LENDER_ALIAS, false);
        assertEq(market.hasAlias(LENDER, LENDER_ALIAS), false);
    }

    function test_configureAlias_Revert_IfContractIsPaused() public {
        configureMarket();

        vm.prank(OWNER);
        market.pause();

        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.configureAlias(LENDER_ALIAS, true);
    }

    function test_configureAlias_Revert_IfAliasIsZeroAddress() public {
        configureMarket();

        vm.prank(LENDER);
        vm.expectRevert(Error.ZeroAddress.selector);
        market.configureAlias(address(0), true);
    }

    function test_configureAlias_Revert_IfAliasIsAlreadyConfigured() public {
        configureMarket();

        vm.startPrank(LENDER);
        market.configureAlias(LENDER_ALIAS, true);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.configureAlias(LENDER_ALIAS, true);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getCreditLineLender() public {
        assertEq(market.getCreditLineLender(address(creditLine)), address(0));

        vm.prank(LENDER);
        market.registerCreditLine(address(creditLine));

        assertEq(market.getCreditLineLender(address(creditLine)), LENDER);
    }

    function test_getLiquidityPoolLender() public {
        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), address(0));

        vm.prank(LENDER);
        market.registerLiquidityPool(address(liquidityPool));

        assertEq(market.getLiquidityPoolLender(address(liquidityPool)), LENDER);
    }

    function test_interestRateFactor() public {
        assertEq(market.interestRateFactor(), Constants.INTEREST_RATE_FACTOR);
    }

    function test_periodInSeconds() public {
        assertEq(market.periodInSeconds(), Constants.PERIOD_IN_SECONDS);
    }

    function test_timeOffset() public {
        (uint256 timeOffset, bool isPositive) = market.timeOffset();
        assertEq(timeOffset, Constants.NEGATIVE_TIME_OFFSET);
        assertEq(isPositive, false);
    }

    // function test_calculatePeriodIndex() public {
    //     uint256 timestamp = 10 ** 6 - 1;
    //     uint256 periodInSeconds = 1 seconds;
    //     uint256 expectedCurrentPeriod = timestamp / periodInSeconds;

    //     assertEq(market.calculatePeriodIndex(timestamp, periodInSeconds), expectedCurrentPeriod);

    //     periodInSeconds = 19 seconds;
    //     for (uint256 i = 0; i <= periodInSeconds; ++i) {
    //         expectedCurrentPeriod = timestamp / periodInSeconds;
    //         assertEq(market.calculatePeriodIndex(timestamp, periodInSeconds), expectedCurrentPeriod);
    //         timestamp += 1;
    //     }
    // }

}

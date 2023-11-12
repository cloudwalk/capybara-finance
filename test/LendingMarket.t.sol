// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Loan} from "src/libraries/Loan.sol";
import {CapybaraNFT} from "src/CapybaraNFT.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";
import {LendingMarket} from "src/LendingMarket.sol";
import {ERC20Mintable} from "./mocks/ERC20Mintable.sol";

import {Error} from "src/libraries/Error.sol";

contract LendingMarketTest is Test {
    event CreditLineRegistered(address indexed lender, address indexed creditLine);
    event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);
    event LoanTaken(uint256 indexed loandId, address indexed borrower, uint256 borrowAmount);
    event LoanRepayment(
        uint256 indexed loandId,
        address indexed repayer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 remainingBalance
    );
    event LoanDurationUpdated(uint256 indexed loandId, uint256 indexed newDuration, uint256 indexed oldDuration);
    event LoanMoratoriumUpdated(uint256 indexed loandId, uint256 indexed newMoratorium, uint256 indexed oldMoratorium);
    event LoanInterestRatePrimaryUpdated(
        uint256 indexed loandId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event LoanInterestRateSecondaryUpdated(
        uint256 indexed loandId, uint256 indexed newInterestRate, uint256 indexed oldInterestRate
    );
    event RegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event LoanStatusChanged(uint256 indexed loandId, Loan.Status indexed newStatus, Loan.Status indexed oldStatus);

    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;
    address public constant ADMIN = 0x97cFe60890C572d2Af20AA160Edabf6E03bf453E;

    string public constant TOKEN_NAME = "CapybaraFinance";
    string public constant TOKEN_SYMBOL = "CAPY";

    uint256 public constant DEPOSIT_AMOUNT = 100;
    uint256 public constant INIT_LOAN_DURATION_IN_PERIODS = 100;
    uint256 public constant INIT_MIN_BORROWER_BORROW_AMOUNT = 50;
    uint256 public constant INIT_MAX_BORROWER_BORROW_AMOUNT = 400;
    uint256 public constant INIT_MIN_BORROW_AMOUNT = 50;
    uint256 public constant INIT_MAX_BORROW_AMOUNT = 500;
    uint256 public constant INIT_PERIOD_IN_SECONDS = 3600;
    uint256 public constant NEW_LOAN_MORATORIUM = 500;
    uint256 public constant INIT_LOAN_INTEREST = 1;
    uint256 public constant ONE_HOUR = 3600;
    uint256 public constant MINT_AMOUNT = 1000000;

    LiquidityPoolAccountable public pool;
    CreditLineConfigurable public line;
    ERC20Mintable public token;
    LendingMarket public marketLogic;
    LendingMarket public market;
    CapybaraNFT public nftLogic;
    CapybaraNFT public nft;
    LendingRegistry public registryLogic;
    LendingRegistry public registry;

    function setUp() public {
        token = new ERC20Mintable(MINT_AMOUNT);
        nftLogic = new CapybaraNFT();
        marketLogic = new LendingMarket();
        registryLogic = new LendingRegistry();

        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftLogic), "");
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");

        market = LendingMarket(address(marketProxy));
        registry = LendingRegistry(address(registryProxy));
        nft = CapybaraNFT(address(nftProxy));

        nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));
        market.initialize(address(nft));
        registry.initialize(address(market));

        market.setRegistry(address(registry));

        pool = new LiquidityPoolAccountable(address(market), address(this));
        line = new CreditLineConfigurable(address(market), address(this));

        token.approve(address(pool), type(uint256).max);
        token.approve(address(market), type(uint256).max);

        vm.prank(address(pool));
        token.approve(address(market), type(uint256).max);
    }

    function test_initialize_Revert_IfNFTAddressZero() public {
        marketLogic = new LendingMarket();
        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");

        market = LendingMarket(address(marketProxy));
        vm.expectRevert(Error.InvalidAddress.selector);
        market.initialize(address(0));
    }

    function test_pause() public {
        assertEq(market.paused(), false);

        market.pause();

        assertEq(market.paused(), true);
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        assertEq(market.paused(), false);
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        market.pause();
    }

    function test_pause_Revert_IfContractIsPaused() public {
        market.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        market.pause();
    }

    function test_unpause() public {
        assertEq(market.paused(), false);
        market.pause();
        assertEq(market.paused(), true);
        market.unpause();
        assertEq(market.paused(), false);
    }

    function test_unpause_Revert_IfContractIsNotPaused() public {
        assertEq(market.paused(), false);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        market.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        assertEq(market.paused(), false);
        market.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        market.unpause();
    }

    function test_registerCreditLine() public {
        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineRegistered(address(this), address(line));
        registry.registerCreditLine(address(this), address(line));

        assertEq(market.getLender(address(line)), address(this));
    }

    function test_registerCreditLine_Revert_IfLenderAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerCreditLine(address(0), address(line));
    }

    function test_registerCreditLine_Revert_IfCreditLineAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerCreditLine(address(this), address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        registry.registerCreditLine(address(this), address(line));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        registry.registerCreditLine(address(this), address(line));
    }

    function test_registerCreditLine_Revert_IfCallerNotRegistry() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerCreditLine(address(this), address(line));
    }

    function test_registerLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolRegistered(address(this), address(pool));
        registry.registerLiquidityPool(address(this), address(pool));

        assertEq(market.getLiquidityPool(address(this)), address(pool));
    }

    function test_registerLiquidityPool_Revert_lfLenderAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerLiquidityPool(address(0), address(pool));
    }

    function test_registerLiquidityPool_Revert_IfPoolAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerLiquidityPool(address(this), address(0));
    }

    function test_registerLiquidityPool_Revert_IfPoolIsAlreadyRegistered() public {
        registry.registerLiquidityPool(address(this), address(pool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        registry.registerLiquidityPool(address(this), address(pool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.registerLiquidityPool(address(this), address(pool));
    }

    function test_setRegistry() public {
        vm.expectEmit(true, true, true, true, address(market));
        emit RegistryUpdated(address(this), address(registry));
        market.setRegistry(address(this));
    }

    function test_setRegistry_RevertIfInvalidAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        market.setRegistry(address(0));
    }

    function test_setRegistry_RevertIfAlreadyConfigured() public {
        vm.expectRevert(Error.AlreadyConfigured.selector);
        market.setRegistry(address(registry));
    }

    function test_takeLoan() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanTaken(0, address(this), DEPOSIT_AMOUNT);
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.initialBorrowAmount, DEPOSIT_AMOUNT);
        assertEq(loan.borrower, address(this));
    }

    function test_takeLoan_Revert_IfCreditLineIsZeroAddress() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        vm.expectRevert(Error.InvalidAddress.selector);
        market.takeLoan(address(0), DEPOSIT_AMOUNT);
    }

    function test_takeLoan_Revert_IfAmountIsZero() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        vm.expectRevert(Error.InvalidAmount.selector);
        market.takeLoan(address(line), 0);
    }

    function test_takeLoan_Revert_IfCreditLineNotRegistered() public {
        registry.registerLiquidityPool(address(this), address(pool));
        vm.expectRevert(LendingMarket.CreditLineNotRegistered.selector);
        market.takeLoan(address(line), DEPOSIT_AMOUNT);
    }

    function test_takeLoan_Revert_IfLiquidityPoolNotRegistered() public {
        registry.registerCreditLine(address(this), address(line));
        vm.expectRevert(LendingMarket.LiquidityPoolNotRegistered.selector);
        market.takeLoan(address(line), DEPOSIT_AMOUNT);
    }

    function test_repayLoan() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanRepayment(0, address(this), address(this), DEPOSIT_AMOUNT, 0);
        market.repayLoan(0, DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.trackedBorrowAmount, 0);
    }

    function test_repayLoan_partial() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        market.repayLoan(0, DEPOSIT_AMOUNT - 1);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.trackedBorrowAmount, 1);
    }

    function test_repayLoan_Revert_IfRepayerIsZeroAddress() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.prank(address(0));
        vm.expectRevert(Error.InvalidAddress.selector);
        market.repayLoan(0, DEPOSIT_AMOUNT);
    }

    function test_repayLoan_Revert_IfAmountIsZero() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(0, 0);
    }

    function test_repayLoan_Revert_IfLoanDoesNotExist() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();

        vm.expectRevert(LendingMarket.LoanNotExist.selector);
        market.repayLoan(0, DEPOSIT_AMOUNT);
    }

    function test_repayLoan_Revert_IfLoanHasInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        market.repayLoan(0, DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.trackedBorrowAmount, 0);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.repayLoan(0, DEPOSIT_AMOUNT);
    }

    function test_repayLoan_Revert_IfAmountIsGreaterThanBorrowAmount() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(Error.InvalidAmount.selector);
        market.repayLoan(0, DEPOSIT_AMOUNT + 1);
    }

    function test_freeze() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        skip(ONE_HOUR);
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanStatusChanged(0, Loan.Status.Frozen, Loan.Status.Active);
        market.freeze(0);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.freezeDate, market.calculatePeriodDate(loan.periodInSeconds, 0, 0));
    }

    function test_freeze_Revert_IfInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        market.repayLoan(0, DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.trackedBorrowAmount, 0);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.freeze(0);
    }

    function test_freeze_Revert_IfCallerNotLoanHolder() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.freeze(0);
    }

    function test_unfreeze() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        skip(ONE_HOUR);

        market.freeze(0);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.freezeDate, market.calculatePeriodDate(loan.periodInSeconds, 0, 0));

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanStatusChanged(0, Loan.Status.Active, Loan.Status.Frozen);
        market.unfreeze(0);

        loan = market.getLoanStored(0);

        assertEq(loan.freezeDate, 0);
    }

    function unfreeze_IfStatusDidNotChange() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        skip(ONE_HOUR);

        market.freeze(0);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.freezeDate, market.calculatePeriodDate(loan.periodInSeconds, 0, 0));

        market.unfreeze(0);

        loan = market.getLoanStored(0);
        assertEq(loan.freezeDate, 0);

        market.unfreeze(0);
        loan = market.getLoanStored(0);
        assertEq(loan.freezeDate, 0);
    }

    function test_unfreeze_Revert_If_InappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.unfreeze(0);
    }

    function test_updateLoanDuration() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.durationInPeriods, INIT_LOAN_DURATION_IN_PERIODS);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanDurationUpdated(0, INIT_LOAN_DURATION_IN_PERIODS + 1, INIT_LOAN_DURATION_IN_PERIODS);
        market.updateLoanDuration(0, INIT_LOAN_DURATION_IN_PERIODS + 1);

        loan = market.getLoanStored(0);

        assertEq(loan.durationInPeriods, INIT_LOAN_DURATION_IN_PERIODS + 1);
    }

    function test_updateLoanDuration_Revert_IfInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        market.repayLoan(0, DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.updateLoanDuration(0, INIT_LOAN_DURATION_IN_PERIODS + 1);
    }

    function test_updateLoanDuration_Revert_IfNewDurationIsLess() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanDuration.selector);
        market.updateLoanDuration(0, INIT_LOAN_DURATION_IN_PERIODS - 1);
    }

    function test_updateLoanDuration_Revert_IfCallerNotLoanHolder() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanDuration(0, INIT_LOAN_DURATION_IN_PERIODS + 1);
    }

    function test_updateLoanMoratorium() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanMoratoriumUpdated(0, NEW_LOAN_MORATORIUM, 0);
        market.updateLoanMoratorium(0, NEW_LOAN_MORATORIUM);
    }

    function test_updateLoanMoratorium_Revert_IfCallerNotLoanHolder() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanMoratorium(0, NEW_LOAN_MORATORIUM);
    }

    function test_updateLoanMoratorium_Revert_IfInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);
        market.repayLoan(0, DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.updateLoanMoratorium(0, NEW_LOAN_MORATORIUM);
    }

    function test_updateLoanMoratorium_Revert_IfInappropriateLoanMoratorium() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanMoratorium.selector);
        market.updateLoanMoratorium(0, 0);
    }

    function test_updateLoanInterestRatePrimary() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.interestRatePrimary, INIT_LOAN_INTEREST);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRatePrimaryUpdated(0, 0, INIT_LOAN_INTEREST);
        market.updateLoanInterestRatePrimary(0, 0);

        loan = market.getLoanStored(0);

        assertEq(loan.interestRatePrimary, 0);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfCallerNotLoanHolder() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.interestRatePrimary, INIT_LOAN_INTEREST);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRatePrimary(0, 0);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);
        market.repayLoan(0, DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.updateLoanInterestRatePrimary(0, 0);
    }

    function test_updateLoanInterestRatePrimary_Revert_IfInappropriateInterestRate() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRatePrimary(0, 3);
    }

    function test_updateLoanInterestRateSecondary() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.interestRateSecondary, INIT_LOAN_INTEREST);

        vm.expectEmit(true, true, true, true, address(market));
        emit LoanInterestRateSecondaryUpdated(0, 0, INIT_LOAN_INTEREST);
        market.updateLoanInterestRateSecondary(0, 0);

        loan = market.getLoanStored(0);

        assertEq(loan.interestRateSecondary, 0);
    }

    function test_updateLoanInterestRateSecondary_IfCallerNotLoanHolder() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        Loan.State memory loan = market.getLoanStored(0);

        assertEq(loan.interestRateSecondary, INIT_LOAN_INTEREST);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        market.updateLoanInterestRateSecondary(0, 0);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfInappropriateStatus() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);
        market.repayLoan(0, DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateLoanStatus.selector);
        market.updateLoanInterestRateSecondary(0, 0);
    }

    function test_updateLoanInterestRateSecondary_Revert_IfInappropriateInterestRate() public {
        registry.registerCreditLine(address(this), address(line));
        registry.registerLiquidityPool(address(this), address(pool));
        configureCredit();
        market.takeLoan(address(line), DEPOSIT_AMOUNT);

        vm.expectRevert(LendingMarket.InappropriateInterestRate.selector);
        market.updateLoanInterestRateSecondary(0, 3);
    }

    function test_updateLender() public {
        vm.expectRevert(Error.NotImplemented.selector);
        market.updateLender(address(line), ADMIN);
    }

    function test_getLender() public {
        registry.registerCreditLine(address(this), address(line));

        assertEq(market.getLender(address(line)), address(this));
    }

    function test_getLiquidityPool() public {
        registry.registerLiquidityPool(address(this), address(pool));

        assertEq(market.getLiquidityPool(address(this)), address(pool));
    }

    function test_getLoanCurrent() public {
        market.getLoanCurrent(0);
    }

    function configureCredit() internal {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(address(this), config);

        line.configureToken(address(token));

        pool.deposit(address(line), DEPOSIT_AMOUNT);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/libraries/Loan.sol";
import { Error } from "src/libraries/Error.sol";
import { Interest } from "src/libraries/Interest.sol";
import { SafeCast } from "src/libraries/SafeCast.sol";

import { ICreditLineConfigurable } from "src/interfaces/ICreditLineConfigurable.sol";
import { CreditLineConfigurable } from "src/lines/CreditLineConfigurable.sol";

/// @title CreditLineConfigurableTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `CreditLineConfigurable` contract.
contract CreditLineConfigurableTest is Test {
    using SafeCast for uint256;

    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event ConfigureAdmin(address indexed admin, bool adminStatus);
    event TokenConfigured(address creditLine, address indexed token);
    event ConfigureCreditLine(address indexed creditLine, ICreditLineConfigurable.CreditLineConfig config);
    event ConfigureBorrower(
        address indexed creditLine, address indexed borrower, ICreditLineConfigurable.BorrowerConfig config
    );

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineConfigurable public creditLine;

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant TOKEN_1 = address(bytes20(keccak256("token_1")));
    address public constant TOKEN_2 = address(bytes20(keccak256("token_2")));
    address public constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address public constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant BORROWER_1 = address(bytes20(keccak256("borrower_1")));
    address public constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address public constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address public constant LOAN_TREASURY = address(bytes20(keccak256("loan_treasury")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint64 public constant CREDIT_LINE_CONFIG_MIN_BORROW_AMOUNT = 400;
    uint64 public constant CREDIT_LINE_CONFIG_MAX_BORROW_AMOUNT = 900;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_PRIMARY = 3;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_PRIMARY = 7;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_INTEREST_RATE_SECONDARY = 4;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_INTEREST_RATE_SECONDARY = 8;
    uint32 public constant CREDIT_LINE_CONFIG_INTEREST_RATE_FACTOR = 1000;
    uint32 public constant CREDIT_LINE_CONFIG_PERIOD_IN_SECONDS = 600;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_DURATION_IN_PERIODS = 20;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_DURATION_IN_PERIODS = 200;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_COST_RATE = 10;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_COST_RATE = 50;
    uint32 public constant CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_COST_RATE = 10;
    uint32 public constant CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_COST_RATE = 50;

    uint32 public constant BORROWER_CONFIG_EXPIRATION = 1000;
    uint64 public constant BORROWER_CONFIG_MIN_BORROW_AMOUNT = 500;
    uint64 public constant BORROWER_CONFIG_MAX_BORROW_AMOUNT = 800;
    uint32 public constant BORROWER_CONFIG_MIN_DURATION_IN_PERIODS = 25;
    uint32 public constant BORROWER_CONFIG_MAX_DURATION_IN_PERIODS = 35;
    uint32 public constant BORROWER_CONFIG_INTEREST_RATE_PRIMARY = 5;
    uint32 public constant BORROWER_CONFIG_INTEREST_RATE_SECONDARY = 6;
    uint32 public constant BORROWER_CONFIG_ADDON_FIXED_COST_RATE = 15;
    uint32 public constant BORROWER_CONFIG_ADDON_PERIOD_COST_RATE = 20;
    bool public constant BORROWER_CONFIG_AUTOREPAYMENT = true;
    Interest.Formula public constant BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy public constant BORROWER_CONFIG_BORROW_POLICY_DECREASE =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    uint32 public constant DURATION_IN_PERIODS = 30;
    uint16 public constant KIND_1 = 1;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(MARKET, LENDER_1, TOKEN_1);
    }

    function configureCreditLine() public returns (ICreditLineConfigurable.CreditLineConfig memory) {
        vm.startPrank(LENDER_1);
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        creditLine.configureAdmin(ADMIN, true);
        creditLine.configureCreditLine(config);
        vm.stopPrank();
        return config;
    }

    function assertTrueBorrowerConfig(
        ICreditLineConfigurable.BorrowerConfig memory config1,
        ICreditLineConfigurable.BorrowerConfig memory config2
    ) internal {
        assertTrue(
            config1.expiration == config2.expiration &&
            config1.minBorrowAmount == config2.minBorrowAmount &&
            config1.maxBorrowAmount == config2.maxBorrowAmount &&
            config1.minDurationInPeriods == config2.minDurationInPeriods &&
            config1.maxDurationInPeriods == config2.maxDurationInPeriods &&
            config1.interestRatePrimary == config2.interestRatePrimary &&
            config1.interestRateSecondary == config2.interestRateSecondary &&
            config1.addonFixedCostRate == config2.addonFixedCostRate &&
            config1.addonPeriodCostRate == config2.addonPeriodCostRate &&
            uint256(config1.interestFormula) == uint256(config2.interestFormula) &&
            uint256(config1.borrowPolicy) == uint256(config2.borrowPolicy) &&
            config1.autoRepayment == config2.autoRepayment
        );
    }

    function assertFalseBorrowerConfig(
        ICreditLineConfigurable.BorrowerConfig memory config1,
        ICreditLineConfigurable.BorrowerConfig memory config2
    ) internal {
        assertFalse(
            config1.expiration == config2.expiration &&
            config1.minBorrowAmount == config2.minBorrowAmount &&
            config1.maxBorrowAmount == config2.maxBorrowAmount &&
            config1.minDurationInPeriods == config2.minDurationInPeriods &&
            config1.maxDurationInPeriods == config2.maxDurationInPeriods &&
            config1.interestRatePrimary == config2.interestRatePrimary &&
            config1.interestRateSecondary == config2.interestRateSecondary &&
            config1.addonFixedCostRate == config2.addonFixedCostRate &&
            config1.addonPeriodCostRate == config2.addonPeriodCostRate &&
            uint256(config1.interestFormula) == uint256(config2.interestFormula) &&
            uint256(config1.borrowPolicy) == uint256(config2.borrowPolicy) &&
            config1.autoRepayment == config2.autoRepayment
        );
    }

    function assertTrueCreditLineConfig(
        ICreditLineConfigurable.CreditLineConfig memory config1,
        ICreditLineConfigurable.CreditLineConfig memory config2
    ) internal {
        assertTrue(
            config1.treasury == config2.treasury &&
            config1.periodInSeconds == config2.periodInSeconds &&
            config1.minDurationInPeriods == config2.minDurationInPeriods &&
            config1.maxDurationInPeriods == config2.maxDurationInPeriods &&
            config1.minBorrowAmount == config2.minBorrowAmount &&
            config1.maxBorrowAmount == config2.maxBorrowAmount  &&
            config1.minInterestRatePrimary == config2.minInterestRatePrimary &&
            config1.maxInterestRatePrimary == config2.maxInterestRatePrimary &&
            config1.minInterestRateSecondary == config2.minInterestRateSecondary &&
            config1.maxInterestRateSecondary == config2.maxInterestRateSecondary &&
            config1.interestRateFactor == config2.interestRateFactor &&
            config1.addonRecipient == config2.addonRecipient &&
            config1.minAddonFixedCostRate == config2.minAddonFixedCostRate &&
            config1.maxAddonFixedCostRate == config2.maxAddonFixedCostRate &&
            config1.minAddonPeriodCostRate == config2.minAddonPeriodCostRate &&
            config1.maxAddonPeriodCostRate == config2.maxAddonPeriodCostRate
        );
    }

    function assertFalseCreditLineConfig(
        ICreditLineConfigurable.CreditLineConfig memory config1,
        ICreditLineConfigurable.CreditLineConfig memory config2
    ) internal {
        assertFalse(
            config1.treasury == config2.treasury &&
            config1.periodInSeconds == config2.periodInSeconds &&
            config1.minDurationInPeriods == config2.minDurationInPeriods &&
            config1.maxDurationInPeriods == config2.maxDurationInPeriods &&
            config1.minBorrowAmount == config2.minBorrowAmount &&
            config1.maxBorrowAmount == config2.maxBorrowAmount  &&
            config1.minInterestRatePrimary == config2.minInterestRatePrimary &&
            config1.maxInterestRatePrimary == config2.maxInterestRatePrimary &&
            config1.minInterestRateSecondary == config2.minInterestRateSecondary &&
            config1.maxInterestRateSecondary == config2.maxInterestRateSecondary &&
            config1.interestRateFactor == config2.interestRateFactor &&
            config1.addonRecipient == config2.addonRecipient &&
            config1.minAddonFixedCostRate == config2.minAddonFixedCostRate &&
            config1.maxAddonFixedCostRate == config2.maxAddonFixedCostRate &&
            config1.minAddonPeriodCostRate == config2.minAddonPeriodCostRate &&
            config1.maxAddonPeriodCostRate == config2.maxAddonPeriodCostRate
        );
    }

    function initBorrowerConfig(uint256 blockTimestamp)
        public
        pure
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            expiration: (blockTimestamp + BORROWER_CONFIG_EXPIRATION).toUint32(),
            minBorrowAmount: BORROWER_CONFIG_MIN_BORROW_AMOUNT,
            maxBorrowAmount: BORROWER_CONFIG_MAX_BORROW_AMOUNT,
            minDurationInPeriods: BORROWER_CONFIG_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: BORROWER_CONFIG_MAX_DURATION_IN_PERIODS,
            interestRatePrimary: BORROWER_CONFIG_INTEREST_RATE_PRIMARY,
            interestRateSecondary: BORROWER_CONFIG_INTEREST_RATE_SECONDARY,
            addonFixedCostRate: BORROWER_CONFIG_ADDON_FIXED_COST_RATE,
            addonPeriodCostRate: BORROWER_CONFIG_ADDON_PERIOD_COST_RATE,
            interestFormula: BORROWER_CONFIG_INTEREST_FORMULA_COMPOUND,
            borrowPolicy: BORROWER_CONFIG_BORROW_POLICY_DECREASE,
            autoRepayment: BORROWER_CONFIG_AUTOREPAYMENT
        });
    }

    function initBorrowerConfigs(uint256 blockTimestamp)
        public
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

    function initCreditLineConfig() public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
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
            addonRecipient: ADDON_RECIPIENT,
            minAddonFixedCostRate: CREDIT_LINE_CONFIG_MIN_ADDON_FIXED_COST_RATE,
            maxAddonFixedCostRate: CREDIT_LINE_CONFIG_MAX_ADDON_FIXED_COST_RATE,
            minAddonPeriodCostRate: CREDIT_LINE_CONFIG_MIN_ADDON_PERIOD_COST_RATE,
            maxAddonPeriodCostRate: CREDIT_LINE_CONFIG_MAX_ADDON_PERIOD_COST_RATE
        });
    }

    // -------------------------------------------- //
    //  Test initializer                            //
    // -------------------------------------------- //

    function test_initializer() public {
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(MARKET, LENDER_1, TOKEN_1);
        assertEq(creditLine.market(), MARKET);
        assertEq(creditLine.lender(), LENDER_1);
        assertEq(creditLine.owner(), LENDER_1);
        assertEq(creditLine.token(), TOKEN_1);
    }

    function test_initializer_Revert_IfMarketIsZeroAddress() public {
        creditLine = new CreditLineConfigurable();
        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.initialize(address(0), LENDER_1, TOKEN_1);
    }

    function test_initializer_Revert_IfLenderIsZeroAddress() public {
        creditLine = new CreditLineConfigurable();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        creditLine.initialize(MARKET, address(0), TOKEN_1);
    }

    function test_initializer_Revert_IfTokenIsZeroAddress() public {
        creditLine = new CreditLineConfigurable();
        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.initialize(MARKET, LENDER_1, address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(MARKET, LENDER_1, TOKEN_1);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        creditLine.initialize(MARKET, LENDER_2, TOKEN_2);
    }

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

    function test_pause() public {
        assertEq(creditLine.paused(), false);
        vm.prank(LENDER_1);
        creditLine.pause();
        assertEq(creditLine.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(LENDER_1);
        creditLine.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        creditLine.pause();
    }

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

    function test_unpause() public {
        vm.startPrank(LENDER_1);
        assertEq(creditLine.paused(), false);
        creditLine.pause();
        assertEq(creditLine.paused(), true);
        creditLine.unpause();
        assertEq(creditLine.paused(), false);
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(creditLine.paused(), false);
        vm.prank(LENDER_1);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        creditLine.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(LENDER_1);
        creditLine.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        creditLine.unpause();
    }

    // -------------------------------------------- //
    //  Test `configureAdmin` function              //
    // -------------------------------------------- //

    function test_configureAdmin() public {
        assertEq(creditLine.isAdmin(ADMIN), false);

        vm.startPrank(LENDER_1);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureAdmin(ADMIN, true);
        creditLine.configureAdmin(ADMIN, true);

        assertEq(creditLine.isAdmin(ADMIN), true);

        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureAdmin(ADMIN, false);
        creditLine.configureAdmin(ADMIN, false);

        assertEq(creditLine.isAdmin(ADMIN), false);
    }

    function test_configureAdmin_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        creditLine.configureAdmin(ADMIN, true);
    }

    function test_configureAdmin_Revert_IfAdminIsZeroAddress() public {
        vm.prank(LENDER_1);
        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.configureAdmin(address(0), true);
    }

    function test_configureAdmin_Revert_IfAdminIsAlreadyConfigured() public {
        vm.startPrank(LENDER_1);
        creditLine.configureAdmin(ADMIN, true);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        creditLine.configureAdmin(ADMIN, true);
    }

    // -------------------------------------------- //
    //  Test `configureCreditLine` function         //
    // -------------------------------------------- //

    function test_configureCreditLine() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        assertFalseCreditLineConfig(config, creditLine.creditLineConfiguration());

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureCreditLine(address(creditLine), config);
        creditLine.configureCreditLine(config);

        assertTrueCreditLineConfig(config, creditLine.creditLineConfiguration());
    }

    function test_configureCreditLine_Revert_IfCallerNotOwner() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfPeriodInSecondsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.periodInSeconds = 0;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfInterestRateFactorIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.interestRateFactor = 0;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinMinBorrowAmountGreaterThanMaxBorrowAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minBorrowAmount = config.maxBorrowAmount + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinDurationInPeriodsGreaterThanMaxDurationInPeriods() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minDurationInPeriods = config.maxDurationInPeriods + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinInterestRatePrimaryIsGreaterThanMaxInterestRatePrimary() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minInterestRatePrimary = config.maxInterestRatePrimary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinInterestRateSecondaryIsGreaterThanMaxInterestRateSecondary() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minInterestRateSecondary = config.maxInterestRateSecondary + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinAddonFixedCostRateIsGreaterThanMaxAddonFixedCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minAddonFixedCostRate = config.maxAddonFixedCostRate + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinAddonPeriodCostRateIsGreaterThanMaxAddonPeriodCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minAddonPeriodCostRate = config.maxAddonPeriodCostRate + 1;

        vm.prank(LENDER_1);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureCreditLine(config);
    }

    // -------------------------------------------- //
    //  Test `configureBorrower` function           //
    // -------------------------------------------- //

    function test_configureBorrower() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        assertFalseBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureBorrower(address(creditLine), BORROWER_1, config);
        creditLine.configureBorrower(BORROWER_1, config);

        assertTrueBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));
    }

    function test_configureBorrower_Revert_IfContractIsPaused() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(LENDER_1);
        creditLine.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfCallerNotAdmin() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfBorrowerIsZeroAddress() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.configureBorrower(address(0), config);
    }

    function test_configureBorrower_Revert_IfMinDurationInPeriodsIsGreaterThanMaxDurationInPeriods() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.minDurationInPeriods = config.maxDurationInPeriods + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfMinDurationInPeriodsIsLessThanCreditLineMaxDurationInPeriods() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.minDurationInPeriods = creditLineConfig.minDurationInPeriods - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfMaxDurationInPeriodsIsGreaterThanCreditLineMaxDurationInPeriods() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.maxDurationInPeriods = creditLineConfig.maxDurationInPeriods + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfMinBorrowAmountIsGreaterThanMaxBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.minBorrowAmount = config.maxBorrowAmount + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfMinBorrowAmountIsLessThanCreditLineMinBorrowAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.minBorrowAmount = creditLineConfig.minBorrowAmount - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfMaxBorrowAmountIsGreaterThanCreditLineMaxBorrowAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.maxBorrowAmount = creditLineConfig.maxBorrowAmount + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfInterestRatePrimaryIsLessThanCreditLineMinInterestRatePrimary() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.interestRatePrimary = creditLineConfig.minInterestRatePrimary - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfInterestRatePrimaryIsGreaterThanCreditLineMaxInterestRatePrimary()
        public
    {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.interestRatePrimary = creditLineConfig.maxInterestRatePrimary + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfInterestRateSecondaryIsLessThanCreditLineMinInterestRateSecondary()
        public
    {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.interestRateSecondary = creditLineConfig.minInterestRateSecondary - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfInterestRateSecondaryIsGreaterThanCreditLineMaxInterestRateSecondary()
        public
    {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.interestRateSecondary = creditLineConfig.maxInterestRateSecondary + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonFixedCostRateIsLessThanCreditLineMinAddonFixedCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonFixedCostRate = creditLineConfig.minAddonFixedCostRate - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonFixedCostRateIsGreaterThanCreditLineMaxAddonFixedCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonFixedCostRate = creditLineConfig.maxAddonFixedCostRate + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonPeriodCostRateIsLessThanCreditLineMinAddonPeriodCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonPeriodCostRate = creditLineConfig.minAddonPeriodCostRate - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonPeriodCostRateIsGreaterThanCreditLineMaxAddonPeriodCostRate()
        public
    {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonPeriodCostRate = creditLineConfig.maxAddonPeriodCostRate + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);
    }

    // -------------------------------------------- //
    //  Test `configureBorrowers` function          //
    // -------------------------------------------- //

    function test_configureBorrowers() public {
        configureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        for (uint256 i = 0; i < borrowers.length; i++) {
            vm.expectEmit(true, true, true, true, address(creditLine));
            emit ConfigureBorrower(address(creditLine), borrowers[i], configs[i]);
            assertFalseBorrowerConfig(configs[i], creditLine.getBorrowerConfiguration(borrowers[i]));
        }

        vm.prank(ADMIN);
        creditLine.configureBorrowers(borrowers, configs);

        for (uint256 i = 0; i < borrowers.length; i++) {
            assertTrueBorrowerConfig(configs[i], creditLine.getBorrowerConfiguration(borrowers[i]));
        }
    }

    function test_configureBorrowers_Revert_IfContractIsPaused() public {
        configureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        vm.prank(LENDER_1);
        creditLine.pause();

        vm.prank(ADMIN);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfCallerNotAdmin() public {
        configureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        creditLine.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfArrayLengthMismatch() public {
        configureCreditLine();

        (, ICreditLineConfigurable.BorrowerConfig[] memory configs) = initBorrowerConfigs(block.timestamp);
        address[] memory borrowers = new address[](1);
        borrowers[0] = BORROWER_1;
        assertNotEq(borrowers.length, configs.length);

        vm.prank(ADMIN);
        vm.expectRevert(Error.ArrayLengthMismatch.selector);
        creditLine.configureBorrowers(borrowers, configs);
    }

    // -------------------------------------------- //
    //  Test `onBeforeLoanTaken` function           //
    // -------------------------------------------- //

    function test_onBeforeLoanTaken_Policy_Keep() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.borrowPolicy = ICreditLineConfigurable.BorrowPolicy.Keep;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);

        vm.prank(MARKET);
        creditLine.onBeforeLoanTaken(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount, 1);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);
    }

    function test_onBeforeLoanTaken_Policy_Reset() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.borrowPolicy = ICreditLineConfigurable.BorrowPolicy.Reset;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);

        vm.prank(MARKET);
        creditLine.onBeforeLoanTaken(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount, 1);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, 0);
    }

    function test_onBeforeLoanTaken_Policy_Decrease() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.borrowPolicy = ICreditLineConfigurable.BorrowPolicy.Decrease;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);

        vm.prank(MARKET);
        creditLine.onBeforeLoanTaken(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount, 1);

        assertEq(
            creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount,
            config.maxBorrowAmount - config.minBorrowAmount
        );
    }

    function test_onBeforeLoanTaken_Revert_IfContractIsPaused() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(LENDER_1);
        creditLine.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.onBeforeLoanTaken(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount, 1);
    }

    function test_onBeforeLoanTaken_Revert_IfCallerIsNotMarket() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        creditLine.onBeforeLoanTaken(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount, 1);
    }

    // -------------------------------------------- //
    //  Test `determineLoanTerms` function          //
    // -------------------------------------------- //

    function test_determineLoanTerms_WithAddon() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms =
            creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, borrowerConfig.minBorrowAmount);

        assertEq(terms.token, creditLine.token());

        assertEq(terms.treasury, creditLineConfig.treasury);
        assertEq(terms.periodInSeconds, creditLineConfig.periodInSeconds);
        assertEq(terms.interestRateFactor, creditLineConfig.interestRateFactor);

        assertEq(terms.durationInPeriods, DURATION_IN_PERIODS);
        assertEq(terms.interestRatePrimary, borrowerConfig.interestRatePrimary);
        assertEq(terms.interestRateSecondary, borrowerConfig.interestRateSecondary);
        assertEq(uint256(terms.interestFormula), uint256(borrowerConfig.interestFormula));
        assertEq(terms.autoRepayment, borrowerConfig.autoRepayment);

        assertEq(terms.addonRecipient, creditLineConfig.addonRecipient);
        assertEq(
            terms.addonAmount,
            creditLine.calculateAddonAmount(
                borrowerConfig.minBorrowAmount,
                DURATION_IN_PERIODS,
                borrowerConfig.addonFixedCostRate,
                borrowerConfig.addonPeriodCostRate
            )
        );
    }

    function test_determineLoanTerms_WithoutAddon_ZeroAddonRates() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        creditLineConfig.minAddonFixedCostRate = 0;
        creditLineConfig.minAddonPeriodCostRate = 0;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonFixedCostRate = 0;
        borrowerConfig.addonPeriodCostRate = 0;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms =
            creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, borrowerConfig.minBorrowAmount);
        assertEq(terms.addonAmount, 0);
    }

    function test_determineLoanTerms_WithoutAddon_ZeroAddonRecipient() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        creditLineConfig.addonRecipient = address(0);

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms =
            creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, borrowerConfig.minBorrowAmount);
        assertEq(terms.addonAmount, 0);
    }

    function test_determineLoanTerms_Revert_IfBorrowerAddressIsZero() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.determineLoanTerms(address(0), DURATION_IN_PERIODS, config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsZero() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, 0);
    }

    function test_determineLoanTerms_Revert_IfConfigurationExpired() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.expiration = (block.timestamp - 1).toUint32();

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(CreditLineConfigurable.BorrowerConfigurationExpired.selector);
        creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsIsGreaterThanMaxBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, config.maxBorrowAmount + 1);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsLessThanMinBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, config.minBorrowAmount - 1);
    }

    function test_determineLoanTerms_Revert_IfDurationInPeriodsIsIsGreaterThanMaxDurationInPeriods() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(CreditLineConfigurable.LoanDurationOutOfRange.selector);
        creditLine.determineLoanTerms(BORROWER_1, config.maxDurationInPeriods + 1, config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfDurationInPeriodsIsLessThanMinDurationInPeriods() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(CreditLineConfigurable.LoanDurationOutOfRange.selector);
        creditLine.determineLoanTerms(BORROWER_1, config.minDurationInPeriods - 1, config.minBorrowAmount);
    }

    // -------------------------------------------- //
    //  Test `calculateAddonAmount` function        //
    // -------------------------------------------- //

    function test_calculateAddonAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        uint256 addonRate = borrowerConfig.addonFixedCostRate + borrowerConfig.addonPeriodCostRate * DURATION_IN_PERIODS;
        uint256 expectedAddonAmount = (borrowerConfig.minBorrowAmount * addonRate) / creditLineConfig.interestRateFactor;

        uint256 actualAddonAmount = creditLine.calculateAddonAmount(
            borrowerConfig.minBorrowAmount,
            DURATION_IN_PERIODS,
            borrowerConfig.addonFixedCostRate,
            borrowerConfig.addonPeriodCostRate
        );
        assertEq(actualAddonAmount, expectedAddonAmount);

        Loan.Terms memory terms =
            creditLine.determineLoanTerms(BORROWER_1, DURATION_IN_PERIODS, borrowerConfig.minBorrowAmount);
        assertEq(terms.addonAmount, expectedAddonAmount);
    }

    // -------------------------------------------- //
    //  Test view functions                         //
    // -------------------------------------------- //

    function test_getBorrowerConfiguration() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        assertFalseBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        assertTrueBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));
    }

    function test_creditLineConfiguration() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        assertFalseCreditLineConfig(config, creditLine.creditLineConfiguration());

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(config);

        assertTrueCreditLineConfig(config, creditLine.creditLineConfiguration());
    }

    function test_isAdmin() public {
        assertFalse(creditLine.isAdmin(ADMIN));

        vm.prank(LENDER_1);
        creditLine.configureAdmin(ADMIN, true);

        assertTrue(creditLine.isAdmin(ADMIN));

        vm.prank(LENDER_1);
        creditLine.configureAdmin(ADMIN, false);

        assertFalse(creditLine.isAdmin(ADMIN));
    }

    function test_lender() public {
        assertEq(creditLine.lender(), LENDER_1);
    }

    function test_market() public {
        assertEq(creditLine.market(), MARKET);
    }

    function test_token() public {
        assertEq(creditLine.token(), TOKEN_1);
    }

    function test_kind() public {
        assertEq(creditLine.kind(), KIND_1);
    }
}

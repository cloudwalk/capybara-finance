// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @title CreditLineConfigurableTest contract
/// @notice Tests for CreditLineConfigurable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineConfigurableTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event AdminConfigured(address indexed admin, bool adminStatus);
    event TokenConfigured(address creditLine, address indexed token);
    event CreditLineConfigurationUpdated(address indexed creditLine, ICreditLineConfigurable.CreditLineConfig config);
    event BorrowerConfigurationUpdated(
        address indexed creditLine, address indexed borrower, ICreditLineConfigurable.BorrowerConfig config
    );

    /************************************************
     *  Errors
     ***********************************************/

    string public constant ERROR_MIN_BORROW_AMOUNT_ZERO = "Min borrow amount cannot be zero";
    string public constant ERROR_MAX_BORROW_AMOUNT_ZERO = "Max borrow amount cannot be zero";
    string public constant ERROR_PERIOD_IN_SECONDS_ZERO = "Period in seconds cannot be zero";
    string public constant ERROR_DURATION_IN_PERIODS_ZERO = "Duration in periods cannot be zero";
    string public constant ERROR_ADDON_RECIPIENT_ADDRESS_ZERO = "Addon recipient address cannot be zero";
    string public constant ERROR_MIN_BORROW_AMOUNT_GREATER_THAN_MAX =
        "Min borrow amount cannot be greater than max borrow amount";

    /************************************************
     *  Variables
     ***********************************************/

    CreditLineConfigurable public line;

    address public immutable LENDER = address(this);

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant TOKEN_1 = address(bytes20(keccak256("token_1")));
    address public constant TOKEN_2 = address(bytes20(keccak256("token_2")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant BORROWER_1 = address(bytes20(keccak256("borrower_1")));
    address public constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address public constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint256 public constant INIT_CREDIT_LINE_MIN_BORROW_AMOUNT = 1000;
    uint256 public constant INIT_CREDIT_LINE_MAX_BORROW_AMOUNT = 5000;
    uint256 public constant INIT_CREDIT_LINE_PERIOD_IN_SECONDS = 3600;
    uint256 public constant INIT_CREDIT_LINE_DURATION_IN_PERIODS = 600;
    uint256 public constant INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE = 15;
    uint256 public constant INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE = 20;

    uint256 public constant INIT_BORROWER_DURATION = 1000;
    uint256 public constant INIT_BORROWER_MIN_BORROW_AMOUNT = 2000;
    uint256 public constant INIT_BORROWER_MAX_BORROW_AMOUNT = 4000;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_PRIMARY = 500;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_SECONDARY = 600;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA = Interest.Formula.Simple;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    uint16 public constant KIND = 1;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        line = new CreditLineConfigurable(MARKET, LENDER);
    }

    function setUpAndConfigureCreditLine() public returns (ICreditLineConfigurable.CreditLineConfig memory) {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        line.configureAdmin(ADMIN, true);
        line.configureCreditLine(config);
        return config;
    }

    function initCreditLineConfig() internal view returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_CREDIT_LINE_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_CREDIT_LINE_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_CREDIT_LINE_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_CREDIT_LINE_DURATION_IN_PERIODS,
            addonPeriodCostRate: INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE,
            addonFixedCostRate: INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE
        });
    }

    function initBorrowerConfig(uint256 blockTimestamp)
        internal
        view
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            expiration: blockTimestamp + INIT_BORROWER_DURATION,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            addonRecipient: ADDON_RECIPIENT,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA,
            policy: INIT_BORROWER_POLICY
        });
    }

    function initBorrowerConfigs(uint256 blockTimestamp)
        internal
        view
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

    function assertEqBorrowerConfig(
        ICreditLineConfigurable.BorrowerConfig memory config1,
        ICreditLineConfigurable.BorrowerConfig memory config2
    ) internal {
        assertEq(config1.minBorrowAmount, config2.minBorrowAmount);
        assertEq(config1.maxBorrowAmount, config2.maxBorrowAmount);
        assertEq(config1.expiration, config2.expiration);
        assertEq(config1.interestRatePrimary, config2.interestRatePrimary);
        assertEq(config1.interestRateSecondary, config2.interestRateSecondary);
        assertEq(config1.addonRecipient, config2.addonRecipient);
        assertEq(uint256(config1.interestFormula), uint256(config2.interestFormula));
        assertEq(uint256(config1.policy), uint256(config2.policy));
    }

    function assertEqCreditLineConfig(
        ICreditLineConfigurable.CreditLineConfig memory config1,
        ICreditLineConfigurable.CreditLineConfig memory config2
    ) internal {
        assertEq(config1.minBorrowAmount, config2.minBorrowAmount);
        assertEq(config1.maxBorrowAmount, config2.maxBorrowAmount);
        assertEq(config1.periodInSeconds, config2.periodInSeconds);
        assertEq(config1.durationInPeriods, config2.durationInPeriods);
        assertEq(config1.addonPeriodCostRate, config2.addonPeriodCostRate);
        assertEq(config1.addonFixedCostRate, config2.addonFixedCostRate);
    }

    /************************************************
     *  Tests for constructor
     ***********************************************/

    function test_constructor() public {
        assertEq(line.market(), MARKET);
        assertEq(line.lender(), LENDER);
        assertEq(line.owner(), LENDER);
    }

    function test_constructor_Revert_IfMarketIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        line = new CreditLineConfigurable(address(0), LENDER);
    }

    function test_constructor_Revert_IfLenderIsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        line = new CreditLineConfigurable(MARKET, address(0));
    }

    /************************************************
     *  Tests for `pause` function
     ***********************************************/

    function test_pause() public {
        vm.prank(LENDER);
        assertEq(line.paused(), false);
        line.pause();
        assertEq(line.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.prank(LENDER);
        line.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.pause();
    }

    function test_pause_Revert_IfCallerIsNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        line.pause();
    }

    /************************************************
     *  Tests for `unpause` function
     ***********************************************/

    function test_unpause() public {
        vm.prank(LENDER);
        assertEq(line.paused(), false);
        line.pause();
        assertEq(line.paused(), true);
        line.unpause();
        assertEq(line.paused(), false);
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(line.paused(), false);
        vm.prank(LENDER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        line.unpause();
    }

    function test_unpause_Revert_IfCallerIsNotOwner() public {
        vm.prank(LENDER);
        line.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        line.unpause();
    }

    /************************************************
     *  Tests for `configureToken` function
     ***********************************************/

    function test_configureToken() public {
        assertEq(line.token(), address(0));
        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(line));
        emit TokenConfigured(address(line), TOKEN_1);
        line.configureToken(TOKEN_1);
        assertEq(line.token(), TOKEN_1);
    }

    function test_configureToken_Revert_IfTokenIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureToken(address(0));
    }

    function test_configureToken_Revert_IfTokenAlreadyConfigured_SameToken() public {
        vm.prank(LENDER);
        line.configureToken(TOKEN_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        line.configureToken(TOKEN_1);
    }

    function test_configureToken_Revert_IfTokenAlreadyConfigured_NewToken() public {
        vm.prank(LENDER);
        line.configureToken(TOKEN_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        line.configureToken(TOKEN_2);
    }

    function test_configureToken_Revert_IfCallerIsNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        line.configureToken(TOKEN_1);
    }

    /************************************************
     *  Tests for `configureAdmin` function
     ***********************************************/

    function test_configureAdmin() public {
        assertEq(line.isAdmin(ADMIN), false);

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(line));
        emit AdminConfigured(ADMIN, true);
        line.configureAdmin(ADMIN, true);

        assertEq(line.isAdmin(ADMIN), true);

        vm.expectEmit(true, true, true, true, address(line));
        emit AdminConfigured(ADMIN, false);
        line.configureAdmin(ADMIN, false);

        assertEq(line.isAdmin(ADMIN), false);
    }

    function test_configureAdmin_Revert_IfAdminIsZeroAddress() public {
        vm.prank(LENDER);
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureAdmin(address(0), true);
    }

    function test_configureAdmin_Revert_IfAdminIsAlreadyConfigured() public {
        vm.prank(LENDER);
        line.configureAdmin(ADMIN, true);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        line.configureAdmin(ADMIN, true);
    }

    function test_configureAdmin_Revert_IfCallerIsNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        line.configureAdmin(ADMIN, true);
    }

    /************************************************
     *  Tests for `configureCreditLine` function
     ***********************************************/

    function test_configureCreditLine() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(line));
        emit CreditLineConfigurationUpdated(address(line), config);
        line.configureCreditLine(config);

        assertEqCreditLineConfig(config, line.creditLineConfiguration());
    }

    function test_configureCreditLine_Revert_IfMinimumBorrowAmountIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minBorrowAmount = 0;

        vm.prank(LENDER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MIN_BORROW_AMOUNT_ZERO
            )
        );
        line.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMaximumBorrowAmountIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.maxBorrowAmount = 0;

        vm.prank(LENDER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MAX_BORROW_AMOUNT_ZERO
            )
        );
        line.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfPeriodInSecondsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.periodInSeconds = 0;

        vm.prank(LENDER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_PERIOD_IN_SECONDS_ZERO
            )
        );
        line.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfDurationInPeriodsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.durationInPeriods = 0;

        vm.prank(LENDER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_DURATION_IN_PERIODS_ZERO
            )
        );
        line.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfMinAmountGreaterThanMaxAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minBorrowAmount = config.maxBorrowAmount + 1;

        vm.prank(LENDER);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MIN_BORROW_AMOUNT_GREATER_THAN_MAX
            )
        );
        line.configureCreditLine(config);
    }

    function test_configureCreditLine_Revert_IfCallerNotTheOwner() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        line.configureCreditLine(config);
    }

    /************************************************
     *  Tests for `configureBorrower` function
     ***********************************************/

    function test_configureBorrower() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true, address(line));
        emit BorrowerConfigurationUpdated(address(line), BORROWER_1, config);
        line.configureBorrower(BORROWER_1, config);

        assertEqBorrowerConfig(config, line.getBorrowerConfiguration(BORROWER_1));
    }

    function test_configureBorrower_Revert_IfBorrowerIsZeroAddress() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureBorrower(address(0), config);
    }

    function test_configureBorrower_Revert_IfCallerIsNotAdmin() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        line.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfContractIsPaused() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(LENDER);
        line.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfAddonAddressNotZero_AddonPeriodCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();
        uint256 addonPeriodCostRate = creditLineConfig.addonPeriodCostRate;

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        // Should not revert if addonPeriodCostRate and addonFixedCostRate are zero
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER);
        line.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        line.configureBorrower(ADMIN, borrowerConfig);

        // Should revert if addonPeriodCostRate is not zero
        creditLineConfig.addonPeriodCostRate = addonPeriodCostRate;

        vm.prank(LENDER);
        line.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_ADDON_RECIPIENT_ADDRESS_ZERO
            )
        );
        line.configureBorrower(ADMIN, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonAddressNotZero_AddonFixedCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();
        uint256 addonFixedCostRate = creditLineConfig.addonFixedCostRate;

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        // Should not revert if addonPeriodCostRate and addonFixedCostRate are zero
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER);
        line.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        line.configureBorrower(ADMIN, borrowerConfig);

        // Should revert if addonFixedCostRate is not zero
        creditLineConfig.addonFixedCostRate = addonFixedCostRate;

        vm.prank(LENDER);
        line.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_ADDON_RECIPIENT_ADDRESS_ZERO
            )
        );
        line.configureBorrower(ADMIN, borrowerConfig);
    }

    /************************************************
     *  Tests for `configureBorrowers` function
     ***********************************************/

    function test_configureBorrowers() public {
        setUpAndConfigureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        for (uint256 i = 0; i < borrowers.length; i++) {
            vm.expectEmit(true, true, true, true, address(line));
            emit BorrowerConfigurationUpdated(address(line), borrowers[i], configs[i]);
        }

        vm.prank(ADMIN);
        line.configureBorrowers(borrowers, configs);

        for (uint256 i = 0; i < borrowers.length; i++) {
            assertEqBorrowerConfig(configs[i], line.getBorrowerConfiguration(borrowers[i]));
        }
    }

    function test_configureBorrowers_Revert_IfArrayLengthMismatch() public {
        setUpAndConfigureCreditLine();

        (, ICreditLineConfigurable.BorrowerConfig[] memory configs) = initBorrowerConfigs(block.timestamp);
        address[] memory borrowers = new address[](1);
        borrowers[0] = BORROWER_1;
        assertNotEq(borrowers.length, configs.length);

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.ArrayLengthMismatch.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfBorrowerIsZeroAddress() public {
        setUpAndConfigureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);
        borrowers[borrowers.length - 1] = address(0);

        vm.prank(ADMIN);
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfCallerIsNotAdmin() public {
        setUpAndConfigureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfContractIsPaused() public {
        setUpAndConfigureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        vm.prank(LENDER);
        line.pause();

        vm.prank(ADMIN);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.configureBorrowers(borrowers, configs);
    }

    /************************************************
     *  Tests for `onLoanTaken` function
     ***********************************************/

    function test_onLoanTaken_Policy_Keep() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Keep;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        line.onLoanTaken(BORROWER_1, config.minBorrowAmount);

        assertEq(line.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);
    }

    function test_onLoanTaken_Policy_Reset() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Reset;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        line.onLoanTaken(BORROWER_1, config.minBorrowAmount);

        assertEq(line.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, 0);
    }

    function test_onLoanTaken_Policy_Decrease() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Decrease;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        line.onLoanTaken(BORROWER_1, config.minBorrowAmount);

        assertEq(
            line.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount - config.minBorrowAmount
        );
    }

    function test_onLoanTaken_Revert_IfCallerIsNotMarket() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        line.onLoanTaken(BORROWER_1, config.minBorrowAmount);
    }

    function test_onLoanTaken_Revert_IfContractIsPaused() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.prank(LENDER);
        line.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.onLoanTaken(BORROWER_1, config.minBorrowAmount);
    }

    /************************************************
     *  Tests for `determineLoanTerms` function
     ***********************************************/

    function test_determineLoanTerms_WithAddon() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms = line.determineLoanTerms(BORROWER_1, borrowerConfig.minBorrowAmount);

        assertEq(terms.token, line.token());
        assertEq(terms.periodInSeconds, creditLineConfig.periodInSeconds);
        assertEq(terms.durationInPeriods, creditLineConfig.durationInPeriods);
        assertEq(terms.interestRatePrimary, borrowerConfig.interestRatePrimary);
        assertEq(terms.interestRateSecondary, borrowerConfig.interestRateSecondary);
        assertEq(uint256(terms.interestFormula), uint256(borrowerConfig.interestFormula));
        assertEq(terms.interestRateFactor, line.INTEREST_RATE_FACTOR());
        assertEq(terms.addonRecipient, borrowerConfig.addonRecipient);
        assertEq(terms.addonAmount, line.calculateAddonAmount(borrowerConfig.minBorrowAmount));
    }

    function test_determineLoanTerms_WithoutAddon() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER);
        line.configureCreditLine(creditLineConfig);

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms = line.determineLoanTerms(BORROWER_1, borrowerConfig.minBorrowAmount);

        assertEq(terms.token, line.token());
        assertEq(terms.periodInSeconds, creditLineConfig.periodInSeconds);
        assertEq(terms.durationInPeriods, creditLineConfig.durationInPeriods);
        assertEq(terms.interestRatePrimary, borrowerConfig.interestRatePrimary);
        assertEq(terms.interestRateSecondary, borrowerConfig.interestRateSecondary);
        assertEq(uint256(terms.interestFormula), uint256(borrowerConfig.interestFormula));
        assertEq(terms.interestRateFactor, line.INTEREST_RATE_FACTOR());
        assertEq(terms.addonRecipient, borrowerConfig.addonRecipient);
        assertEq(terms.addonAmount, 0);
    }

    function test_determineLoanTerms_Revert_IfBorrowerAddressIsZero() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAddress.selector);
        line.determineLoanTerms(address(0), config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsZero() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(ADMIN, 0);
    }

    function test_determineLoanTerms_Revert_IfConfigHasExpired() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.expiration = block.timestamp - 1;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(CreditLineConfigurable.BorrowerConfigurationExpired.selector);
        line.determineLoanTerms(BORROWER_1, config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsGreaterThanMaxBorrowAmount_On_BorrowerConfig() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(BORROWER_1, config.maxBorrowAmount + 1);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsLessThanMinBorrowAmount_On_BorrowerConfig() public {
        setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(BORROWER_1, config.minBorrowAmount - 1);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsGreaterThanMaxBorrowAmount_On_CreditLineConfig() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.maxBorrowAmount = creditLineConfig.maxBorrowAmount + 2;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(BORROWER_1, creditLineConfig.maxBorrowAmount + 1);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsLessThanMinBorrowAmount_On_CreditLineConfig() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = setUpAndConfigureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.minBorrowAmount = creditLineConfig.minBorrowAmount - 2;

        vm.prank(ADMIN);
        line.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(BORROWER_1, creditLineConfig.minBorrowAmount - 1);
    }

    /************************************************
     *  Tests for `calculateAddonAmount` function
     ***********************************************/

    function test_calculateAddonAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory config = setUpAndConfigureCreditLine();

        uint256 amount = 300;
        uint256 INTEREST_RATE_BASE = 10 ** 6;

        uint256 addonRate = config.addonFixedCostRate + config.addonPeriodCostRate * config.durationInPeriods;
        uint256 addonAmount = (amount * addonRate) / INTEREST_RATE_BASE;

        assertEq(line.calculateAddonAmount(amount), addonAmount);
    }

    /************************************************
     *  Tests for view functions
     ***********************************************/

    function test_lender() public {
        assertEq(line.lender(), LENDER);
    }

    function test_market() public {
        assertEq(line.market(), MARKET);
    }

    function test_kind() public {
        assertEq(line.kind(), KIND);
    }
}

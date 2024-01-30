// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {Interest} from "src/libraries/Interest.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";

import {Config} from "test/base/Config.sol";

/// @title CreditLineConfigurableTest contract
/// @notice Contains tests for the CreditLineConfigurable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineConfigurableTest is Test, Config {
    /************************************************
     *  Events
     ***********************************************/

    event ConfigureAdmin(address indexed admin, bool adminStatus);
    event TokenConfigured(address creditLine, address indexed token);
    event ConfigureCreditLine(address indexed creditLine, ICreditLineConfigurable.CreditLineConfig config);
    event ConfigureBorrower(
        address indexed creditLine, address indexed borrower, ICreditLineConfigurable.BorrowerConfig config
    );

    /************************************************
     *  Storage variables
     ***********************************************/

    CreditLineConfigurable public creditLine;

    /************************************************
     *  Setup and configuration
     ***********************************************/

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

    function assertEqBorrowerConfig(
        ICreditLineConfigurable.BorrowerConfig memory config1,
        ICreditLineConfigurable.BorrowerConfig memory config2
    ) internal {
        assertEq(config1.expiration, config2.expiration);
        assertEq(config1.minBorrowAmount, config2.minBorrowAmount);
        assertEq(config1.maxBorrowAmount, config2.maxBorrowAmount);
        assertEq(config1.interestRatePrimary, config2.interestRatePrimary);
        assertEq(config1.interestRateSecondary, config2.interestRateSecondary);
        assertEq(config1.addonRecipient, config2.addonRecipient);
        assertEq(uint256(config1.interestFormula), uint256(config2.interestFormula));
        assertEq(uint256(config1.policy), uint256(config2.policy));
    }

    function assertFalseBorrowerConfig(
        ICreditLineConfigurable.BorrowerConfig memory config1,
        ICreditLineConfigurable.BorrowerConfig memory config2
    ) internal {
        assertFalse(
            config1.expiration == config2.expiration && config1.minBorrowAmount == config2.minBorrowAmount
                && config1.maxBorrowAmount == config2.maxBorrowAmount
                && config1.interestRatePrimary == config2.interestRatePrimary
                && config1.interestRateSecondary == config2.interestRateSecondary
                && config1.addonRecipient == config2.addonRecipient
                && uint256(config1.interestFormula) == uint256(config2.interestFormula)
                && uint256(config1.policy) == uint256(config2.policy)
        );
    }

    function assertEqCreditLineConfig(
        ICreditLineConfigurable.CreditLineConfig memory config1,
        ICreditLineConfigurable.CreditLineConfig memory config2
    ) internal {
        assertEq(config1.periodInSeconds, config2.periodInSeconds);
        assertEq(config1.durationInPeriods, config2.durationInPeriods);
        assertEq(config1.minBorrowAmount, config2.minBorrowAmount);
        assertEq(config1.maxBorrowAmount, config2.maxBorrowAmount);
        assertEq(config1.interestRateFactor, config2.interestRateFactor);
        assertEq(config1.minInterestRatePrimary, config2.minInterestRatePrimary);
        assertEq(config1.maxInterestRatePrimary, config2.maxInterestRatePrimary);
        assertEq(config1.minInterestRateSecondary, config2.minInterestRateSecondary);
        assertEq(config1.maxInterestRateSecondary, config2.maxInterestRateSecondary);
        assertEq(config1.addonPeriodCostRate, config2.addonPeriodCostRate);
        assertEq(config1.addonFixedCostRate, config2.addonFixedCostRate);
    }

    function assertFalseCreditLineConfig(
        ICreditLineConfigurable.CreditLineConfig memory config1,
        ICreditLineConfigurable.CreditLineConfig memory config2
    ) internal {
        assertFalse(
            config1.periodInSeconds == config2.periodInSeconds && config1.durationInPeriods == config2.durationInPeriods
                && config1.minBorrowAmount == config2.minBorrowAmount && config1.maxBorrowAmount == config2.maxBorrowAmount
                && config1.interestRateFactor == config2.interestRateFactor
                && config1.minInterestRatePrimary == config2.minInterestRatePrimary
                && config1.maxInterestRatePrimary == config2.maxInterestRatePrimary
                && config1.minInterestRateSecondary == config2.minInterestRateSecondary
                && config1.maxInterestRateSecondary == config2.maxInterestRateSecondary
                && config1.addonPeriodCostRate == config2.addonPeriodCostRate
                && config1.addonFixedCostRate == config2.addonFixedCostRate
        );
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        creditLine = new CreditLineConfigurable();
        creditLine.initialize(MARKET, LENDER_1, TOKEN_1);
        assertEq(creditLine.market(), MARKET);
        assertEq(creditLine.lender(), LENDER_1);
        assertEq(creditLine.token(), TOKEN_1);
        assertEq(creditLine.owner(), LENDER_1);
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
        creditLine.initialize(MARKET, LENDER_1, TOKEN_1);
    }

    /************************************************
     *  Test `pause` function
     ***********************************************/

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

    /************************************************
     *  Test `unpause` function
     ***********************************************/

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

    /************************************************
     *  Test `configureAdmin` function
     ***********************************************/

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

    /************************************************
     *  Test `configureCreditLine` function
     ***********************************************/

    function test_configureCreditLine() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();

        assertFalseCreditLineConfig(config, creditLine.creditLineConfiguration());

        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureCreditLine(address(creditLine), config);
        creditLine.configureCreditLine(config);

        assertEqCreditLineConfig(config, creditLine.creditLineConfiguration());
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

    function test_configureCreditLine_Revert_IfDurationInPeriodsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.durationInPeriods = 0;

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

    function test_configureCreditLine_Revert_IfMinBorrowAmountIsGreaterThanMaxBorrowAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory config = initCreditLineConfig();
        config.minBorrowAmount = config.maxBorrowAmount + 1;

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

    /************************************************
     *  Test `configureBorrower` function
     ***********************************************/

    function test_configureBorrower() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        assertFalseBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true, address(creditLine));
        emit ConfigureBorrower(address(creditLine), BORROWER_1, config);
        creditLine.configureBorrower(BORROWER_1, config);

        assertEqBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));
    }

    function test_configureBorrower_Revert_IfContractIsPaused() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(LENDER_1);
        creditLine.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfCallerNotAdmin() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        creditLine.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfBorrowerIsZeroAddress() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.configureBorrower(address(0), config);
    }

    function test_configureBorrower_Revert_IfMinBorrowAmountIsGreaterThanMaxBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.minBorrowAmount = config.maxBorrowAmount + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfMinBorrowAmountIsLessThanMinBorrowAmount_On_CreditLineConfig() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.minBorrowAmount = creditLineConfig.minBorrowAmount - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfMaxBorrowAmountIsGreaterThanMaxBorrowAmount_On_CreditLineConfig() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.maxBorrowAmount = creditLineConfig.maxBorrowAmount + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfInterestRatePrimaryIsLessThanMinInterestRatePrimary_On_CreditLineConfig()
        public
    {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.interestRatePrimary = creditLineConfig.minInterestRatePrimary - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfInterestRatePrimaryIsGreaterThanMaxInterestRatePrimary_On_CreditLineConfig(
    ) public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.interestRatePrimary = creditLineConfig.maxInterestRatePrimary + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfInterestRateSecondaryIsLessThanMinInterestRateSecondary_On_CreditLineConfig(
    ) public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.interestRateSecondary = creditLineConfig.minInterestRateSecondary - 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfInterestRateSecondaryIsGreaterThanMaxInterestRateSecondary_On_CreditLineConfig(
    ) public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.interestRateSecondary = creditLineConfig.maxInterestRateSecondary + 1;

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidBorrowerConfiguration.selector);
        creditLine.configureBorrower(BORROWER_1, config);
    }

    function test_configureBorrower_Revert_IfAddonAddressNotZero_AddonPeriodCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        uint256 addonPeriodCostRate = creditLineConfig.addonPeriodCostRate;

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        // Should not revert if addonPeriodCostRate and addonFixedCostRate are zero
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        creditLine.configureBorrower(ADMIN, borrowerConfig);

        // Should revert if addonPeriodCostRate is not zero
        creditLineConfig.addonPeriodCostRate = addonPeriodCostRate;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureBorrower(ADMIN, borrowerConfig);
    }

    function test_configureBorrower_Revert_IfAddonAddressNotZero_AddonFixedCostRate() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        uint256 addonFixedCostRate = creditLineConfig.addonFixedCostRate;

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        // Should not revert if addonPeriodCostRate and addonFixedCostRate are zero
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        creditLine.configureBorrower(ADMIN, borrowerConfig);

        // Should revert if addonFixedCostRate is not zero
        creditLineConfig.addonFixedCostRate = addonFixedCostRate;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        vm.prank(ADMIN);
        vm.expectRevert(CreditLineConfigurable.InvalidCreditLineConfiguration.selector);
        creditLine.configureBorrower(ADMIN, borrowerConfig);
    }

    /************************************************
     *  Test `configureBorrowers` function
     ***********************************************/

    function test_configureBorrowers() public {
        configureCreditLine();

        (address[] memory borrowers, ICreditLineConfigurable.BorrowerConfig[] memory configs) =
            initBorrowerConfigs(block.timestamp);

        for (uint256 i = 0; i < borrowers.length; i++) {
            vm.expectEmit(true, true, true, true, address(creditLine));
            emit ConfigureBorrower(address(creditLine), borrowers[i], configs[i]);
        }

        vm.prank(ADMIN);
        creditLine.configureBorrowers(borrowers, configs);

        for (uint256 i = 0; i < borrowers.length; i++) {
            assertEqBorrowerConfig(configs[i], creditLine.getBorrowerConfiguration(borrowers[i]));
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
        vm.expectRevert(CreditLineConfigurable.ArrayLengthMismatch.selector);
        creditLine.configureBorrowers(borrowers, configs);
    }

    /************************************************
     *  Test `onTakeLoan` function
     ***********************************************/

    function test_onTakeLoan_Policy_Keep() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Keep;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        creditLine.onTakeLoan(BORROWER_1, config.minBorrowAmount);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, config.maxBorrowAmount);
    }

    function test_onTakeLoan_Policy_Reset() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Reset;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        creditLine.onTakeLoan(BORROWER_1, config.minBorrowAmount);

        assertEq(creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount, 0);
    }

    function test_onTakeLoan_Policy_Decrease() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.policy = ICreditLineConfigurable.BorrowPolicy.Decrease;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(MARKET);
        creditLine.onTakeLoan(BORROWER_1, config.minBorrowAmount);

        assertEq(
            creditLine.getBorrowerConfiguration(BORROWER_1).maxBorrowAmount,
            config.maxBorrowAmount - config.minBorrowAmount
        );
    }

    function test_onTakeLoan_Revert_IfContractIsPaused() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(LENDER_1);
        creditLine.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        creditLine.onTakeLoan(BORROWER_1, config.minBorrowAmount);
    }

    function test_onTakeLoan_Revert_IfCallerIsNotMarket() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        creditLine.onTakeLoan(BORROWER_1, config.minBorrowAmount);
    }

    /************************************************
     *  Test `determineLoanTerms` function
     ***********************************************/

    function test_determineLoanTerms_WithAddon() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms = creditLine.determineLoanTerms(BORROWER_1, borrowerConfig.minBorrowAmount);

        assertEq(terms.token, creditLine.token());
        assertEq(terms.periodInSeconds, creditLineConfig.periodInSeconds);
        assertEq(terms.durationInPeriods, creditLineConfig.durationInPeriods);
        assertEq(terms.interestRateFactor, creditLineConfig.interestRateFactor);
        assertEq(terms.interestRatePrimary, borrowerConfig.interestRatePrimary);
        assertEq(terms.interestRateSecondary, borrowerConfig.interestRateSecondary);
        assertEq(uint256(terms.interestFormula), uint256(borrowerConfig.interestFormula));
        assertEq(terms.addonRecipient, borrowerConfig.addonRecipient);
        assertEq(terms.addonAmount, creditLine.calculateAddonAmount(borrowerConfig.minBorrowAmount));
    }

    function test_determineLoanTerms_WithoutAddon() public {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = configureCreditLine();
        creditLineConfig.addonPeriodCostRate = 0;
        creditLineConfig.addonFixedCostRate = 0;

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(creditLineConfig);

        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(block.timestamp);
        borrowerConfig.addonRecipient = address(0);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, borrowerConfig);

        Loan.Terms memory terms = creditLine.determineLoanTerms(BORROWER_1, borrowerConfig.minBorrowAmount);

        assertEq(terms.token, creditLine.token());
        assertEq(terms.periodInSeconds, creditLineConfig.periodInSeconds);
        assertEq(terms.durationInPeriods, creditLineConfig.durationInPeriods);
        assertEq(terms.interestRateFactor, creditLineConfig.interestRateFactor);
        assertEq(terms.interestRatePrimary, borrowerConfig.interestRatePrimary);
        assertEq(terms.interestRateSecondary, borrowerConfig.interestRateSecondary);
        assertEq(uint256(terms.interestFormula), uint256(borrowerConfig.interestFormula));
        assertEq(terms.addonRecipient, borrowerConfig.addonRecipient);
        assertEq(terms.addonAmount, 0);
    }

    function test_determineLoanTerms_Revert_IfBorrowerAddressIsZero() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.ZeroAddress.selector);
        creditLine.determineLoanTerms(address(0), config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsZero() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(ADMIN, 0);
    }

    function test_determineLoanTerms_Revert_IfConfigurationExpired() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);
        config.expiration = block.timestamp - 1;

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(CreditLineConfigurable.BorrowerConfigurationExpired.selector);
        creditLine.determineLoanTerms(BORROWER_1, config.minBorrowAmount);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsIsGreaterThanMaxBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(BORROWER_1, config.maxBorrowAmount + 1);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsLessThanMinBorrowAmount() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        creditLine.determineLoanTerms(BORROWER_1, config.minBorrowAmount - 1);
    }

    /************************************************
     *  Test `calculateAddonAmount` function
     ***********************************************/

    function test_calculateAddonAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory config = configureCreditLine();

        uint256 amount = 300;

        uint256 addonRate = config.addonFixedCostRate + config.addonPeriodCostRate * config.durationInPeriods;
        uint256 addonAmount = (amount * addonRate) / config.interestRateFactor;

        assertEq(creditLine.calculateAddonAmount(amount), addonAmount);
    }

    /************************************************
     *  Test view functions
     ***********************************************/

    function test_getBorrowerConfiguration() public {
        configureCreditLine();

        ICreditLineConfigurable.BorrowerConfig memory config = initBorrowerConfig(block.timestamp);

        assertFalseBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));

        vm.prank(ADMIN);
        creditLine.configureBorrower(BORROWER_1, config);

        assertEqBorrowerConfig(config, creditLine.getBorrowerConfiguration(BORROWER_1));
    }

    function test_creditLineConfiguration() public {
        ICreditLineConfigurable.CreditLineConfig memory config = configureCreditLine();

        assertEqCreditLineConfig(config, creditLine.creditLineConfiguration());

        config.periodInSeconds += 1;
        config.durationInPeriods += 1;
        assertFalseCreditLineConfig(config, creditLine.creditLineConfiguration());

        vm.prank(LENDER_1);
        creditLine.configureCreditLine(config);

        assertEqCreditLineConfig(config, creditLine.creditLineConfiguration());
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

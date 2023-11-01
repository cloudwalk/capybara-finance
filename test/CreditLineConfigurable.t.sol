    // SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Loan} from "src/libraries/Loan.sol";
import {Error} from "../src/libraries/Error.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract CreditLineConfigurableTest is Test {
    event TokenConfigured(address creditLine, address indexed token);
    event AdminConfigured(address indexed admin, bool adminStatus);

    string public constant ERROR_MIN_BORROW_AMOUNT_ZERO = "Min borrow amount cannot be zero";
    string public constant ERROR_MAX_BORROW_AMOUNT_ZERO = "Max borrow amount cannot be zero";
    string public constant ERROR_PERIOD_IN_SECONDS_ZERO = "Period in seconds cannot be zero";
    string public constant ERROR_DURATION_IN_PERIODS_ZERO = "Duration in periods cannot be zero";
    string public constant ERROR_ADDON_RECIPIENT_ADDRESS_ZERO = "Addon recipient address cannot be zero";
    string public constant ERROR_MIN_AMOUNT_GREATER = "Min borrow amount cannot be greater than max borrow amount";

    address[] public borrowers;

    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;
    address public constant ADMIN = 0x97cFe60890C572d2Af20AA160Edabf6E03bf453E;
    address public constant TOKEN = 0xC3FF8fEd0C9eEe5db09b8e65Da3755f7F4a08acE;

    uint256 public constant INIT_LOAN_DURATION_IN_PERIODS = 100;
    uint256 public constant INIT_ADDON_AMOUNT = 100;
    uint256 public constant INIT_MIN_BORROW_AMOUNT = 100;
    uint256 public constant INIT_MAX_BORROW_AMOUNT = 500;
    uint256 public constant INIT_MIN_BORROWER_BORROW_AMOUNT = 200;
    uint256 public constant INIT_MAX_BORROWER_BORROW_AMOUNT = 400;
    uint256 public constant BORROW_AMOUNT = 100;
    uint256 public constant INIT_PERIOD_IN_SECONDS = 3600;
    uint256 public constant INIT_LOAN_INTEREST = 1;
    uint16 public constant KIND = 1;

    ICreditLineConfigurable.BorrowerConfig[] public configs;
    CreditLineConfigurable public line;

    function setUp() public {
        line = new CreditLineConfigurable(address(this), address(this));
    }

    function test_constructor() public {
        assertEq(line.market(), address(this));
        assertEq(line.lender(), address(this));

        assertEq(line.lender(), line.owner());
    }

    function test_constructor_Revert_IfMarketIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        line = new CreditLineConfigurable(address(0), address(this));
    }

    function test_constructor_Revert_IfLenderIsZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
        );
        line = new CreditLineConfigurable(address(this), address(0));
    }

    function test_pause() public {
        assertEq(line.paused(), false);
        line.pause();
        assertEq(line.paused(), true);
    }

    function test_pause_Revert_IfCallerIsNotTheOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        line.pause();
    }

    function test_pause_Revert_IfContractIsPaused() public {
        line.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.pause();
    }

    function test_unpause() public {
        assertEq(line.paused(), false);
        line.pause();
        assertEq(line.paused(), true);
        line.unpause();
        assertEq(line.paused(), false);
    }

    function test_unpause_Revert_IfCallerIsNotTheOwner() public {
        line.pause();
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        line.unpause();
    }

    function test_unpause_RevertIfContractNotPaused() public {
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        line.unpause();
    }

    function test_configureToken() public {
        assertEq(line.token(), address(0));
        vm.expectEmit(true, true, true, true, address(line));
        emit TokenConfigured(address(line), TOKEN);
        line.configureToken(TOKEN);
        assertEq(line.token(), TOKEN);
    }

    function test_configureToken_Revert_IfTokenISZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureToken(address(0));
    }

    function test_configureToken_Revert_IfTokenAlreadyConfigured() public {
        line.configureToken(TOKEN);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        line.configureToken(TOKEN);
    }

    function test_configureToken_Revert_IfCallerIsNotAnOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        line.configureToken(ATTACKER);
    }

    function test_configureAdmin() public {
        assertEq(line.isAdmin(ADMIN), false);
        vm.expectEmit(true, true, true, true, address(line));
        emit AdminConfigured(ADMIN, true);
        line.configureAdmin(ADMIN, true);
        assertEq(line.isAdmin(ADMIN), true);
    }

    function test_configureAdmin_Revert_IfAdminIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureAdmin(address(0), true);
    }

    function test_configureAdmin_Revert_IfAdminIsAlreadyConfigured() public {
        line.configureAdmin(ADMIN, true);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        line.configureAdmin(ADMIN, true);
    }

    function test_configureAdmin_Revert_IfCallerIsNotAnOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        line.configureAdmin(ATTACKER, true);
    }

    function test_configureCreditLine() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureCreditLine(lineConfig);

        assertEq(line.creditLineConfiguration().minBorrowAmount, lineConfig.minBorrowAmount);
        assertEq(line.creditLineConfiguration().maxBorrowAmount, lineConfig.maxBorrowAmount);
        assertEq(line.creditLineConfiguration().periodInSeconds, lineConfig.periodInSeconds);
        assertEq(line.creditLineConfiguration().durationInPeriods, lineConfig.durationInPeriods);
        assertEq(line.creditLineConfiguration().addonPeriodCostRate, lineConfig.addonPeriodCostRate);
        assertEq(line.creditLineConfiguration().addonFixedCostRate, lineConfig.addonFixedCostRate);
    }

    function test_configureCreditLine_Revert_IfMinimumAmountIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: 0,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MIN_BORROW_AMOUNT_ZERO
            )
        );
        line.configureCreditLine(lineConfig);
    }

    function test_configureCreditLine_Revert_IfMaximumAmountIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: 0,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MAX_BORROW_AMOUNT_ZERO
            )
        );
        line.configureCreditLine(lineConfig);
    }

    function test_configureCreditLine_Revert_IfPeriodInSecondsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: 0,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_PERIOD_IN_SECONDS_ZERO
            )
        );
        line.configureCreditLine(lineConfig);
    }

    function test_configureCreditLine_Revert_IfDurationInPeriodsIsZero() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: 0,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_DURATION_IN_PERIODS_ZERO
            )
        );
        line.configureCreditLine(lineConfig);
    }

    function test_configureCreditLine_Revert_IfMinAmountBiggerThanMaxAmount() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MAX_BORROW_AMOUNT + 1,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_MIN_AMOUNT_GREATER
            )
        );
        line.configureCreditLine(lineConfig);
    }

    function test_configureCreditLine_Revert_IfCallerNotOwner() public {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        line.configureCreditLine(lineConfig);
    }

    function test_configureBorrower() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        assertEq(line.getBorrowerConfiguration(ADMIN).interestRatePrimary, config.interestRatePrimary);
        assertEq(line.getBorrowerConfiguration(ADMIN).interestRateSecondary, config.interestRateSecondary);
        assertEq(line.getBorrowerConfiguration(ADMIN).expiration, config.expiration);
    }

    function test_configureBorrower_Revert_IfAddressIsZeroAddress() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureBorrower(address(0), config);
    }

    function test_configureBorrower_Revert_IfAmountIsLessThanLineMinimumAmount() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT - 1,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.configureBorrower(ADMIN, config);
    }

    function test_configureBorrower_Revert_IfAmountIsMoreThanLineMaximumAmount() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT + 1,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.configureBorrower(ADMIN, config);
    }

    function test_configureBorrower_Revert_IfCallerIsNotAdmin() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        assertEq(line.isAdmin(address(this)), false);

        vm.expectRevert(Error.Unauthorized.selector);
        line.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfContractIsPaused() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        line.pause();

        assertEq(line.paused(), true);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.configureBorrower(ATTACKER, config);
    }

    function test_configureBorrower_Revert_IfAddonAddressNotZero() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 1,
            addonFixedCostRate: 1
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        vm.expectRevert(
            abi.encodeWithSelector(
                CreditLineConfigurable.InvalidCreditLineConfiguration.selector, ERROR_ADDON_RECIPIENT_ADDRESS_ZERO
            )
        );
        line.configureBorrower(ADMIN, config);
    }

    function test_configureBorrowers() public {
        line.configureAdmin(address(this), true);

        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });
        line.configureCreditLine(lineConfig);

        borrowers.push(ADMIN);
        borrowers.push(ATTACKER);
        borrowers.push(TOKEN);

        configs.push(config);
        configs.push(config);
        configs.push(config);

        line.configureBorrowers(borrowers, configs);

        assertEq(line.getBorrowerConfiguration(ADMIN).interestRatePrimary, config.interestRatePrimary);
        assertEq(line.getBorrowerConfiguration(ATTACKER).interestRatePrimary, config.interestRatePrimary);
        assertEq(line.getBorrowerConfiguration(TOKEN).interestRatePrimary, config.interestRatePrimary);
    }

    function test_configureBorrowers_Revert_IfArrayLengthMismatch() public {
        line.configureAdmin(address(this), true);

        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });
        line.configureCreditLine(lineConfig);

        borrowers.push(ADMIN);
        borrowers.push(ATTACKER);
        borrowers.push(TOKEN);

        configs.push(config);
        configs.push(config);

        vm.expectRevert(CreditLineConfigurable.ArrayLengthMismatch.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfBorrowerIsZeroAddress() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        borrowers.push(ADMIN);
        borrowers.push(address(0));
        borrowers.push(TOKEN);

        configs.push(config);
        configs.push(config);
        configs.push(config);

        vm.expectRevert(Error.InvalidAddress.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfCallerIsNotAnAdmin() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        borrowers.push(ADMIN);
        borrowers.push(address(this));
        borrowers.push(TOKEN);

        configs.push(config);
        configs.push(config);
        configs.push(config);

        line.configureAdmin(address(this), false);
        assertEq(line.isAdmin(address(this)), false);

        vm.expectRevert(Error.Unauthorized.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_configureBorrowers_Revert_IfContractIsPaused() public {
        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);

        borrowers.push(ADMIN);
        borrowers.push(address(0));
        borrowers.push(TOKEN);

        configs.push(config);
        configs.push(config);
        configs.push(config);

        line.pause();

        assertEq(line.paused(), true);

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.configureBorrowers(borrowers, configs);
    }

    function test_onLoanTaken_ResetPolicy() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Reset
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        line.onLoanTaken(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);

        assertEq(line.getBorrowerConfiguration(ADMIN).maxBorrowAmount, 0);
    }

    function test_onLoanTaken_DecreasePolicy() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        line.onLoanTaken(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);

        assertEq(
            line.getBorrowerConfiguration(address(ADMIN)).maxBorrowAmount,
            INIT_MAX_BORROWER_BORROW_AMOUNT - INIT_MIN_BORROWER_BORROW_AMOUNT
        );
    }

    function test_onLoanTaken_KeepPolicy() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Keep
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        line.onLoanTaken(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);

        assertEq(line.getBorrowerConfiguration(ADMIN).maxBorrowAmount, INIT_MAX_BORROWER_BORROW_AMOUNT);
    }

    function test_onLoanTaken_Revert_IFCallerIsNotMarket() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.prank(ATTACKER);
        vm.expectRevert(Error.Unauthorized.selector);
        line.onLoanTaken(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);
    }

    function test_onLoanTaken_Revert_IfContractIsPaused() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        line.pause();

        vm.prank(ATTACKER);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        line.onLoanTaken(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);
    }

    function test_determineLoanTerms() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        Loan.Terms memory res = line.determineLoanTerms(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);

        assertEq(res.token, line.token());
        assertEq(res.periodInSeconds, lineConfig.periodInSeconds);
        assertEq(res.durationInPeriods, lineConfig.durationInPeriods);
        assertEq(res.interestRatePrimary, config.interestRatePrimary);
        assertEq(res.interestRateSecondary, config.interestRateSecondary);
        assertEq(res.addonRecipient, config.addonRecipient);
        assertEq(res.addonAmount, config.addonAmount);
    }

    function test_determineLoanTerms_CalculateAddonAmount() public {
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
            addonRecipient: address(this),
            addonAmount: INIT_ADDON_AMOUNT,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        Loan.Terms memory res = line.determineLoanTerms(ADMIN, INIT_MIN_BORROWER_BORROW_AMOUNT);

        assertEq(res.token, line.token());
        assertEq(res.periodInSeconds, lineConfig.periodInSeconds);
        assertEq(res.durationInPeriods, lineConfig.durationInPeriods);
        assertEq(res.interestRatePrimary, config.interestRatePrimary);
        assertEq(res.interestRateSecondary, config.interestRateSecondary);
        assertEq(res.addonRecipient, config.addonRecipient);
        assertEq(res.addonAmount, line.calculateAddonAmount(INIT_ADDON_AMOUNT));
    }

    function test_determineLoanTerms_Revert_IfBorrowerAddressIsZero() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.expectRevert(Error.InvalidAddress.selector);
        line.determineLoanTerms(address(0), INIT_MIN_BORROW_AMOUNT);
    }

    function test_determineLoanTerms_Revert_IfBorrowAmountIsZero() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(ADMIN, 0);
    }

    function test_determineLoanTerms_Revert_IfConfigIsExpired() public {
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
            expiration: block.timestamp - 1,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.expectRevert(CreditLineConfigurable.BorrowerConfigurationExpired.selector);
        line.determineLoanTerms(address(ADMIN), INIT_MIN_BORROWER_BORROW_AMOUNT);
    }

    function test_determineLoanTerms_Revert_IfAmountIsMoreThanMaxBorrowAmount() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(address(ADMIN), INIT_MAX_BORROWER_BORROW_AMOUNT + 1);
    }

    function test_determineLoanTerms_Revert_IfAmountIsLessThanMinBorrowAmount() public {
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
            addonAmount: 0,
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(ADMIN, config);

        vm.expectRevert(Error.InvalidAmount.selector);
        line.determineLoanTerms(address(ADMIN), INIT_MIN_BORROW_AMOUNT - 1);
    }

    function test_calculateAddonAmount() public {
        uint256 INTEREST_RATE_BASE = 10 ** 6;
        uint256 amount = 300;

        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        uint256 addonRate =
            lineConfig.addonFixedCostRate + lineConfig.addonPeriodCostRate * lineConfig.durationInPeriods;
        uint256 res = (amount * addonRate) / INTEREST_RATE_BASE;

        assertEq(line.calculateAddonAmount(amount), res);
    }

    function test_market() public {
        assertEq(line.market(), address(this));
    }

    function test_lender() public {
        assertEq(line.lender(), address(this));
    }

    function test_kind() public {
        assertEq(line.kind(), KIND);
    }
}

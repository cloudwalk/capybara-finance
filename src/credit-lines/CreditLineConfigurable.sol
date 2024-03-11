// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "../common/libraries/Loan.sol";
import { Error } from "../common/libraries/Error.sol";
import { SafeCast } from "../common/libraries/SafeCast.sol";

import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";
import { ICreditLineConfigurable } from "../common/interfaces/ICreditLineConfigurable.sol";

/// @title CreditLineConfigurable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Implementation of the configurable credit line contract.
contract CreditLineConfigurable is OwnableUpgradeable, PausableUpgradeable, ICreditLineConfigurable {
    using SafeCast for uint256;
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @dev The address of the lending market.
    address internal _market;

    /// @dev The address of the credit line token.
    address internal _token;

    /// @dev The mapping of account to its admin status.
    mapping(address => bool) internal _admins;

    /// @dev The mapping of borrower to its configuration.
    mapping(address => BorrowerConfig) internal _borrowers;

    /// @dev The configuration of the credit line.
    CreditLineConfig internal _config;

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the credit line configuration is invalid.
    error InvalidCreditLineConfiguration();

    /// @notice Thrown when the borrower configuration is invalid.
    error InvalidBorrowerConfiguration();

    /// @notice Thrown when the borrower configuration has expired.
    error BorrowerConfigurationExpired();

    /// @notice Thrown when the borrow policy is unsupported.
    error UnsupportedBorrowPolicy();

    /// @notice Thrown when the loan duration is out of range.
    error LoanDurationOutOfRange();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @notice Throws if called by any account other than the lending market.
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the admin.
    modifier onlyAdmin() {
        if (!_admins[msg.sender]) {
            revert Error.Unauthorized();
        }
        _;
    }

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @notice Initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    /// @param lender_ The address of the lender.
    /// @param token_ The address of the token.
    function initialize(address market_, address lender_, address token_) external initializer {
        __CreditLineConfigurable_init(market_, lender_, token_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    /// @param lender_ The address of the lender.
    /// @param token_ The address of the token.
    function __CreditLineConfigurable_init(
        address market_,
        address lender_,
        address token_
    ) internal onlyInitializing {
        __Ownable_init_unchained(lender_);
        __Pausable_init_unchained();
        __CreditLineConfigurable_init_unchained(market_, token_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    /// @param token_ The address of the token.
    function __CreditLineConfigurable_init_unchained(address market_, address token_) internal onlyInitializing {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (token_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
        _token = token_;
    }

    // -------------------------------------------- //
    //  Owner functions                             //
    // -------------------------------------------- //

    /// @notice Pauses the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureAdmin(address admin, bool isAdmin) external onlyOwner {
        if (admin == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_admins[admin] == isAdmin) {
            revert Error.AlreadyConfigured();
        }

        _admins[admin] = isAdmin;

        emit AdminConfigured(admin, isAdmin);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureCreditLine(CreditLineConfig memory config) external onlyOwner {
        if (config.periodInSeconds == 0) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.interestRateFactor == 0) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minBorrowAmount > config.maxBorrowAmount) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minDurationInPeriods > config.maxDurationInPeriods) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minInterestRatePrimary > config.maxInterestRatePrimary) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minInterestRateSecondary > config.maxInterestRateSecondary) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minAddonFixedCostRate > config.maxAddonFixedCostRate) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minAddonPeriodCostRate > config.maxAddonPeriodCostRate) {
            revert InvalidCreditLineConfiguration();
        }

        _config = config;

        emit CreditLineConfigured(address(this), config);
    }

    // -------------------------------------------- //
    //  Admin functions                             //
    // -------------------------------------------- //

    /// @inheritdoc ICreditLineConfigurable
    function configureBorrower(address borrower, BorrowerConfig memory config) external whenNotPaused onlyAdmin {
        _configureBorrower(borrower, config);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureBorrowers(
        address[] memory borrowers,
        BorrowerConfig[] memory configs
    ) external whenNotPaused onlyAdmin {
        if (borrowers.length != configs.length) {
            revert Error.ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < borrowers.length; i++) {
            _configureBorrower(borrowers[i], configs[i]);
        }
    }

    // -------------------------------------------- //
    //  Market functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ICreditLine
    function onBeforeLoanTaken(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods,
        uint256 loandId
    ) external whenNotPaused onlyMarket returns (Loan.Terms memory terms) {
        terms = determineLoanTerms(borrower, borrowAmount, durationInPeriods);

        BorrowerConfig storage borrowerConfig = _borrowers[borrower];

        if (borrowerConfig.borrowPolicy == BorrowPolicy.Reset) {
            borrowerConfig.maxBorrowAmount = 0;
        } else if (borrowerConfig.borrowPolicy == BorrowPolicy.Decrease) {
            borrowerConfig.maxBorrowAmount -= borrowAmount.toUint64();
        } else if (borrowerConfig.borrowPolicy == BorrowPolicy.Keep) { } else {
            // NOTE: This should never happen since all possible policies are checked above
            revert UnsupportedBorrowPolicy();
        }
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ICreditLine
    function determineLoanTerms(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods
    ) public view returns (Loan.Terms memory terms) {
        if (borrower == address(0)) {
            revert Error.ZeroAddress();
        }
        if (borrowAmount == 0) {
            revert Error.InvalidAmount();
        }

        BorrowerConfig storage borrowerConfig = _borrowers[borrower];

        if (block.timestamp > borrowerConfig.expiration) {
            revert BorrowerConfigurationExpired();
        }
        if (borrowAmount > borrowerConfig.maxBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (borrowAmount < borrowerConfig.minBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (durationInPeriods < borrowerConfig.minDurationInPeriods) {
            revert LoanDurationOutOfRange();
        }
        if (durationInPeriods > borrowerConfig.maxDurationInPeriods) {
            revert LoanDurationOutOfRange();
        }

        terms.token = _token;
        terms.treasury = _config.treasury;
        terms.addonRecipient = _config.addonRecipient;
        terms.periodInSeconds = _config.periodInSeconds;
        terms.interestRateFactor = _config.interestRateFactor;
        terms.durationInPeriods = durationInPeriods.toUint32();
        terms.interestRatePrimary = borrowerConfig.interestRatePrimary;
        terms.interestRateSecondary = borrowerConfig.interestRateSecondary;
        terms.interestFormula = borrowerConfig.interestFormula;
        terms.autoRepayment = borrowerConfig.autoRepayment;

        if (terms.addonRecipient != address(0)) {
            terms.addonAmount = calculateAddonAmount(
                borrowAmount, durationInPeriods, borrowerConfig.addonFixedCostRate, borrowerConfig.addonPeriodCostRate
            ).toUint64();
        }
    }

    /// @inheritdoc ICreditLineConfigurable
    function getBorrowerConfiguration(address borrower) external view override returns (BorrowerConfig memory) {
        return _borrowers[borrower];
    }

    /// @inheritdoc ICreditLineConfigurable
    function creditLineConfiguration() external view override returns (CreditLineConfig memory) {
        return _config;
    }

    /// @inheritdoc ICreditLineConfigurable
    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    /// @inheritdoc ICreditLine
    function market() external view returns (address) {
        return _market;
    }

    /// @inheritdoc ICreditLine
    function lender() external view returns (address) {
        return owner();
    }

    /// @inheritdoc ICreditLine
    function token() external view returns (address) {
        return _token;
    }

    /// @inheritdoc ICreditLine
    function kind() external pure returns (uint16) {
        return 1;
    }

    /// @notice Calculates the addon payment amount.
    /// @param amount The initial principal amount of the loan.
    /// @param durationInPeriods The duration of the loan in periods.
    /// @param addonFixedCostRate The fixed cost rate of the loan addon payment.
    /// @param addonPeriodCostRate The period cost rate of the loan addon payment.
    function calculateAddonAmount(
        uint256 amount,
        uint256 durationInPeriods,
        uint256 addonFixedCostRate,
        uint256 addonPeriodCostRate
    ) public view returns (uint256) {
        uint256 addonRate = addonPeriodCostRate * durationInPeriods + addonFixedCostRate;
        addonRate = addonRate * _config.interestRateFactor / (_config.interestRateFactor - addonRate);
        return (amount * addonRate) / _config.interestRateFactor;
    }

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @dev Updates the borrower configuration.
    /// @param borrower The address of the borrower to configure.
    /// @param config The new borrower configuration to be applied.
    function _configureBorrower(address borrower, BorrowerConfig memory config) internal {
        if (borrower == address(0)) {
            revert Error.ZeroAddress();
        }

        // NOTE: We don't check for expiration here, because
        // it can be used for disabling a borrower by setting it to 0.

        if (config.minBorrowAmount > config.maxBorrowAmount) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.minBorrowAmount < _config.minBorrowAmount) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.maxBorrowAmount > _config.maxBorrowAmount) {
            revert InvalidBorrowerConfiguration();
        }

        if (config.minDurationInPeriods > config.maxDurationInPeriods) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.minDurationInPeriods < _config.minDurationInPeriods) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.maxDurationInPeriods > _config.maxDurationInPeriods) {
            revert InvalidBorrowerConfiguration();
        }

        if (config.interestRatePrimary < _config.minInterestRatePrimary) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.interestRatePrimary > _config.maxInterestRatePrimary) {
            revert InvalidBorrowerConfiguration();
        }

        if (config.interestRateSecondary < _config.minInterestRateSecondary) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.interestRateSecondary > _config.maxInterestRateSecondary) {
            revert InvalidBorrowerConfiguration();
        }

        if (config.addonFixedCostRate < _config.minAddonFixedCostRate) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.addonFixedCostRate > _config.maxAddonFixedCostRate) {
            revert InvalidBorrowerConfiguration();
        }

        if (config.addonPeriodCostRate < _config.minAddonPeriodCostRate) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.addonPeriodCostRate > _config.maxAddonPeriodCostRate) {
            revert InvalidBorrowerConfiguration();
        }

        _borrowers[borrower] = config;

        emit BorrowerConfigured(address(this), borrower, config);
    }
}

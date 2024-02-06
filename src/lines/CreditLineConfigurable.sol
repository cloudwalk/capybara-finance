// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "../libraries/Loan.sol";
import {Error} from "../libraries/Error.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {ICreditLine} from "../interfaces/core/ICreditLine.sol";
import {ICreditLineConfigurable} from "../interfaces/ICreditLineConfigurable.sol";

/// @title CreditLineConfigurable contract
/// @notice Implementation of the configurable credit line contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineConfigurable is OwnableUpgradeable, PausableUpgradeable, ICreditLine, ICreditLineConfigurable {
    using SafeCast for uint256;
    /************************************************
     *  Storage
     ***********************************************/

    /// @notice The address of the associated lending market
    address internal _market;

    /// @notice The address of the associated token
    address internal _token;

    /// @notice The credit line configuration
    CreditLineConfig internal _config;

    /// @notice The mapping of account to admin status
    mapping(address => bool) internal _admins;

    /// @notice The mapping of borrower to borrower configuration
    mapping(address => BorrowerConfig) internal _borrowers;

    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the credit line configuration is invalid
    error InvalidCreditLineConfiguration();

    /// @notice Thrown when the borrower configuration is invalid
    error InvalidBorrowerConfiguration();

    /// @notice Thrown when the borrower configuration has expired
    error BorrowerConfigurationExpired();

    /// @notice Thrown when the borrow policy is unsupported
    error UnsupportedBorrowPolicy();

    /// @notice Thrown when array lengths do not match
    error ArrayLengthMismatch();

    /************************************************
     *  Modifiers
     ***********************************************/

    /// @notice Throws if called by any account other than the market
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the admin
    modifier onlyAdmin() {
        if (!_admins[msg.sender]) {
            revert Error.Unauthorized();
        }
        _;
    }

    /************************************************
     *  Initializers
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    /// @param lender_ The address of the associated lender
    /// @param token_ The address of the associated token
    function initialize(address market_, address lender_, address token_) external initializer {
        __CreditLineConfigurable_init(market_, lender_, token_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    /// @param lender_ The address of the associated lender
    /// @param token_ The address of the associated token
    function __CreditLineConfigurable_init(address market_, address lender_, address token_)
        internal
        onlyInitializing
    {
        __Ownable_init_unchained(lender_);
        __Pausable_init_unchained();
        __CreditLineConfigurable_init_unchained(market_, lender_, token_);
    }

    /// @notice Unchained internal initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    /// @param lender_ The address of the associated lender
    /// @param token_ The address of the associated token
    function __CreditLineConfigurable_init_unchained(address market_, address lender_, address token_)
        internal
        onlyInitializing
    {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (lender_ == address(0)) {
            // NOTE: This should never happen since the lender is the contract owner,
            // and its address is checked to be non-zero by the Ownable contract
            revert Error.ZeroAddress();
        }
        if (token_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
        _token = token_;
    }

    /************************************************
     *  Owner functions
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureAdmin(address admin, bool adminStatus) external onlyOwner {
        if (admin == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_admins[admin] == adminStatus) {
            revert Error.AlreadyConfigured();
        }

        _admins[admin] = adminStatus;

        emit ConfigureAdmin(admin, adminStatus);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureCreditLine(CreditLineConfig memory config) external onlyOwner {
        if (config.periodInSeconds == 0) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.interestRateFactor == 0) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minDurationInPeriods > config.maxDurationInPeriods) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minBorrowAmount > config.maxBorrowAmount) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minInterestRatePrimary > config.maxInterestRatePrimary) {
            revert InvalidCreditLineConfiguration();
        }
        if (config.minInterestRateSecondary > config.maxInterestRateSecondary) {
            revert InvalidCreditLineConfiguration();
        }

        _config = config;

        emit ConfigureCreditLine(address(this), config);
    }

    /************************************************
     *  Admin functions
     ***********************************************/

    /// @inheritdoc ICreditLineConfigurable
    function configureBorrower(address borrower, BorrowerConfig memory config) external whenNotPaused onlyAdmin {
        _configureBorrower(borrower, config);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureBorrowers(address[] memory borrowers, BorrowerConfig[] memory configs)
        external
        whenNotPaused
        onlyAdmin
    {
        if (borrowers.length != configs.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < borrowers.length; i++) {
            _configureBorrower(borrowers[i], configs[i]);
        }
    }

    /************************************************
     *  Market functions
     ***********************************************/

    /// @inheritdoc ICreditLine
    function onBeforeLoanTaken(address borrower, uint256 amount, uint256 loandId)
        external
        whenNotPaused
        onlyMarket
        returns (Loan.Terms memory terms)
    {
        loandId; // Silence compiler warning

        terms = determineLoanTerms(borrower, amount);

        BorrowerConfig storage borrowerConfig = _borrowers[borrower];

        if (borrowerConfig.policy == BorrowPolicy.Reset) {
            borrowerConfig.maxBorrowAmount = 0;
        } else if (borrowerConfig.policy == BorrowPolicy.Decrease) {
            borrowerConfig.maxBorrowAmount = (uint256(borrowerConfig.maxBorrowAmount) - amount).toUint64();
        } else if (borrowerConfig.policy == BorrowPolicy.Keep) {} else {
            // NOTE: This should never happen since all possible policies are checked above
            revert UnsupportedBorrowPolicy();
        }
    }

    /************************************************
     *  View functions
     ***********************************************/

    /// @inheritdoc ICreditLine
    function determineLoanTerms(address borrower, uint256 amount) public view returns (Loan.Terms memory terms) {
        if (borrower == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        BorrowerConfig storage borrowerConfig = _borrowers[borrower];

        if (block.timestamp > borrowerConfig.expiration) {
            revert BorrowerConfigurationExpired();
        }
        if (amount > borrowerConfig.maxBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (amount < borrowerConfig.minBorrowAmount) {
            revert Error.InvalidAmount();
        }

        terms.token = _token;
        terms.interestRateFactor = _config.interestRateFactor;
        terms.periodInSeconds = _config.periodInSeconds;
        terms.durationInPeriods = borrowerConfig.durationInPeriods;
        terms.interestRatePrimary = borrowerConfig.interestRatePrimary;
        terms.interestRateSecondary = borrowerConfig.interestRateSecondary;
        terms.interestFormula = borrowerConfig.interestFormula;
        terms.addonRecipient = borrowerConfig.addonRecipient;
        terms.autoRepayment = borrowerConfig.autoRepayment;

        if (terms.addonRecipient != address(0)) {
            terms.addonAmount = calculateAddonAmount(amount, borrowerConfig).toUint64();
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

    /// @notice Calculates the additional payment amount
    /// @param amount The initial principal amount of the loan
    /// @param borrowerConfig The borrower configuration
    function calculateAddonAmount(uint256 amount, BorrowerConfig memory borrowerConfig) public view returns (uint256) {
        uint256 addonRate = uint256(_config.addonFixedCostRate) +
            uint256(_config.addonPeriodCostRate) * uint256(borrowerConfig.durationInPeriods);
        return (amount * addonRate) / uint256(_config.interestRateFactor);
    }

    /************************************************
     *  Internal functions
     ***********************************************/

    /// @notice Updates the borrower configuration
    /// @param borrower The address of the borrower
    /// @param config The new borrower configuration
    function _configureBorrower(address borrower, BorrowerConfig memory config) internal {
        if (borrower == address(0)) {
            revert Error.ZeroAddress();
        }

        // NOTE: we don't check for expiration here
        // because expiration can be used to disable a borrower

        if (config.durationInPeriods == 0) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.durationInPeriods < _config.minDurationInPeriods) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.durationInPeriods > _config.maxDurationInPeriods) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.minBorrowAmount > config.maxBorrowAmount) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.minBorrowAmount < _config.minBorrowAmount) {
            revert InvalidBorrowerConfiguration();
        }
        if (config.maxBorrowAmount > _config.maxBorrowAmount) {
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
        if (_config.addonPeriodCostRate != 0 || _config.addonFixedCostRate != 0) {
            if (config.addonRecipient == address(0)) {
                revert InvalidCreditLineConfiguration();
            }
        }

        _borrowers[borrower] = config;

        emit ConfigureBorrower(address(this), borrower, config);
    }
}
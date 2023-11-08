// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Loan} from "../libraries/Loan.sol";
import {Error} from "../libraries/Error.sol";

import {ICreditLine} from "../interfaces/core/ICreditLine.sol";
import {ICreditLineConfigurable} from "../interfaces/ICreditLineConfigurable.sol";

/// @title CreditLineConfigurable contract
/// @notice Implementation of the configurable credit line contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineConfigurable is Ownable, Pausable, ICreditLine, ICreditLineConfigurable {
    /************************************************
     *  Storage
     ***********************************************/

    /// @notice The rate base used together with interest rate
    uint256 public constant INTEREST_RATE_FACTOR = 10 ** 6;

    /// @notice The address of the associated lending market
    address internal immutable _market;

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
    /// @param message The error message
    error InvalidCreditLineConfiguration(string message);

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
     *  Constructor
     ***********************************************/

    /// @notice Contract constructor
    /// @param market_ The address of the associated lending market
    /// @param lender_ The address of the associated lender
    constructor(address market_, address lender_) Ownable(lender_) {
        if (market_ == address(0)) {
            revert Error.InvalidAddress();
        }
        if (lender_ == address(0)) {
            // This should never happen since the lender is the contract owner,
            // and the owner address is checked to be non-zero by the Ownable
            revert Error.InvalidAddress();
        }

        _market = market_;
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
    function configureToken(address token_) external onlyOwner {
        if (token_ == address(0)) {
            revert Error.InvalidAddress();
        }
        if (_token != address(0)) {
            revert Error.AlreadyConfigured();
        }

        _token = token_;

        emit TokenConfigured(address(this), token_);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureAdmin(address admin, bool adminStatus) external onlyOwner {
        if (admin == address(0)) {
            revert Error.InvalidAddress();
        }
        if (_admins[admin] == adminStatus) {
            revert Error.AlreadyConfigured();
        }

        _admins[admin] = adminStatus;

        emit AdminConfigured(admin, adminStatus);
    }

    /// @inheritdoc ICreditLineConfigurable
    function configureCreditLine(CreditLineConfig memory config) external onlyOwner {
        _configureCreditLine(config);
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
    function onLoanTaken(address borrower, uint256 amount)
        external
        whenNotPaused
        onlyMarket
        returns (Loan.Terms memory terms)
    {
        terms = determineLoanTerms(borrower, amount);

        BorrowerConfig storage borrowerConfig = _borrowers[borrower];

        if (borrowerConfig.policy == BorrowPolicy.Reset) {
            borrowerConfig.maxBorrowAmount = 0;
        } else if (borrowerConfig.policy == BorrowPolicy.Decrease) {
            borrowerConfig.maxBorrowAmount -= amount;
        } else if (borrowerConfig.policy == BorrowPolicy.Keep) {
            // Do nothing here
        } else {
            revert UnsupportedBorrowPolicy();
        }
    }

    /************************************************
     *  View functions
     ***********************************************/

    /// @inheritdoc ICreditLine
    function determineLoanTerms(address borrower, uint256 amount) public view returns (Loan.Terms memory terms) {
        if (borrower == address(0)) {
            revert Error.InvalidAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        BorrowerConfig memory borrowerConfig = _borrowers[borrower];
        CreditLineConfig memory lineConfig = _config;

        if (block.timestamp > borrowerConfig.expiration) {
            revert BorrowerConfigurationExpired();
        }
        if (amount > borrowerConfig.maxBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (amount < borrowerConfig.minBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (amount > _config.maxBorrowAmount) {
            revert Error.InvalidAmount();
        }
        if (amount < _config.minBorrowAmount) {
            revert Error.InvalidAmount();
        }

        terms.token = _token;
        terms.periodInSeconds = _config.periodInSeconds;
        terms.durationInPeriods = _config.durationInPeriods;
        terms.interestRatePrimary = borrowerConfig.interestRatePrimary;
        terms.interestRateSecondary = borrowerConfig.interestRateSecondary;
        terms.interestFormula = borrowerConfig.interestFormula;
        terms.addonRecipient = borrowerConfig.addonRecipient;
        terms.interestRateFactor = INTEREST_RATE_FACTOR;

        if (terms.addonRecipient != address(0)) {
            terms.addonAmount = calculateAddonAmount(amount);
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
    function calculateAddonAmount(uint256 amount) public view returns (uint256) {
        CreditLineConfig storage config = _config;
        uint256 addonRate = config.addonFixedCostRate + config.addonPeriodCostRate * config.durationInPeriods;
        return (amount * addonRate) / INTEREST_RATE_FACTOR;
    }

    /************************************************
     *  Internal functions
     ***********************************************/

    /// @notice Updates the credit line configuration
    /// @param config The new credit line configuration
    function _configureCreditLine(CreditLineConfig memory config) internal {
        if (config.minBorrowAmount == 0) {
            revert InvalidCreditLineConfiguration("Min borrow amount cannot be zero");
        }
        if (config.maxBorrowAmount == 0) {
            revert InvalidCreditLineConfiguration("Max borrow amount cannot be zero");
        }
        if (config.periodInSeconds == 0) {
            revert InvalidCreditLineConfiguration("Period in seconds cannot be zero");
        }
        if (config.durationInPeriods == 0) {
            revert InvalidCreditLineConfiguration("Duration in periods cannot be zero");
        }
        if (config.minBorrowAmount > config.maxBorrowAmount) {
            revert InvalidCreditLineConfiguration("Min borrow amount cannot be greater than max borrow amount");
        }

        _config = config;

        emit CreditLineConfigurationUpdated(address(this), config);
    }

    /// @notice Updates the borrower configuration
    /// @param borrower The address of the borrower
    /// @param config The new borrower configuration
    function _configureBorrower(address borrower, BorrowerConfig memory config) internal {
        if (borrower == address(0)) {
            revert Error.InvalidAddress();
        }
        if (_config.addonPeriodCostRate != 0 || _config.addonFixedCostRate != 0) {
            if (config.addonRecipient == address(0)) {
                revert InvalidCreditLineConfiguration("Addon recipient address cannot be zero");
            }
        }

        _borrowers[borrower] = config;

        emit BorrowerConfigurationUpdated(address(this), borrower, config);
    }
}

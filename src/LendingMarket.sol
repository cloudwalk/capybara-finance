// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Loan} from "./libraries/Loan.sol";
import {Error} from "./libraries/Error.sol";
import {Interest} from "./libraries/Interest.sol";
import {InterestMath} from "./libraries/InterestMath.sol";

import {ICapybaraNFT} from "./interfaces/core/ICapybaraNFT.sol";
import {ILendingMarket} from "./interfaces/core/ILendingMarket.sol";
import {ILiquidityPool} from "./interfaces/core/ILiquidityPool.sol";
import {ICreditLine} from "./interfaces/core/ICreditLine.sol";

import {LendingMarketStorage} from "./LendingMarketStorage.sol";

/// @title LendingMarket contract
/// @notice Implementation of the lending market contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarket is
    LendingMarketStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ILendingMarket
{
    using SafeERC20 for IERC20;

    /************************************************
     *  ERRORS
     ***********************************************/

    /// @notice Thrown when the loan does not exist
    error LoanNotExist();

    /// @notice Thrown when the loan is already repaid
    error LoanAlreadyRepaid();

    /// @notice Thrown when the credit line is not registered
    error CreditLineNotRegistered();

    /// @notice Thrown when the liquidity pool is not registered
    error LiquidityPoolNotRegistered();

    /// @notice Thrown when the credit line is already registered
    error CreditLineAlreadyRegistered();

    /// @notice Thrown when the liquidity pool is already registered
    error LiquidityPoolAlreadyRegistered();

    /// @notice Thrown when the loan status is inappropriate
    error InappropriateLoanStatus();

    /// @notice Thrown when the interest rate is inappropriate
    error InappropriateInterestRate();

    /// @notice Thrown when the loan duration is inappropriate
    error InappropriateLoanDuration();

    /// @notice Thrown when the loan moratorium is inappropriate
    error InappropriateLoanMoratorium();

    /************************************************
     *  MODIFIERS
     ***********************************************/

    /// @notice Throws if called by any account other than the registry
    modifier onlyRegistry() {
        if (msg.sender != _registry) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the loan holder
    modifier onlyLoanHolder(uint256 loanId) {
        if (IERC721(_nft).ownerOf(loanId) != msg.sender) {
            revert Error.Unauthorized();
        }
        _;
    }

    /************************************************
     *  CONSTRUCTOR
     ***********************************************/

    /// @dev Constructor that prohibits the initialization of the implementation of the upgradable contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /************************************************
     *  INITIALIZERS
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param nft_ The address of the NFT token associated with the lending market
    function initialize(address nft_) external initializer {
        __LendingMarket_init(nft_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param nft_ The address of the NFT token associated with the lending market
    function __LendingMarket_init(address nft_) internal onlyInitializing {
        //__Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __UUPSUpgradeable_init_unchained();
        __LendingMarket_init_unchained(nft_);
    }

    /// @notice Unchained internal initializer of the upgradable contract
    /// @param nft_ The address of the NFT token associated with the lending market
    function __LendingMarket_init_unchained(address nft_) internal onlyInitializing {
        if (nft_ == address(0)) {
            revert Error.InvalidAddress();
        }

        _nft = nft_;
    }

    /************************************************
     *  OWNER FUNCTIONS
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the address of the registry contract
    /// @param newRegistry The address of the new registry contract
    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == address(0)) {
            revert Error.InvalidAddress();
        }
        if (newRegistry == _registry) {
            revert Error.AlreadyConfigured();
        }

        emit RegistryUpdated(newRegistry, _registry);

        _registry = newRegistry;
    }

    /************************************************
     *  REGISTRY FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistry {
        _registerCreditLine(lender, creditLine);
    }

    /// @inheritdoc ILendingMarket
    function registerLiquidityPool(address lender, address liquidityPool) external whenNotPaused onlyRegistry {
        _registerLiquidityPool(lender, liquidityPool);
    }

    /************************************************
     *  BORROWER FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function takeLoan(address creditLine, uint256 amount) external whenNotPaused {
        _takeLoan(msg.sender, creditLine, amount);
    }

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 amount) external whenNotPaused {
        _repayLoan(msg.sender, loanId, amount);
    }

    /************************************************
     *  LOAN HOLDER FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function freeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Frozen || status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }

        loan.freezeDate = calculatePeriodDate(loan.periodInSeconds, 0, 0);

        Loan.Status newStatus = _getStatus(loan);

        if (newStatus != status) {
            emit LoanStatusChanged(loanId, newStatus, status);
        }
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external onlyLoanHolder(loanId) whenNotPaused {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status != Loan.Status.Frozen) {
            revert InappropriateLoanStatus();
        }

        uint256 currentDate = calculatePeriodDate(loan.periodInSeconds, 0, 0);
        uint256 newTrackDate = currentDate - (loan.freezeDate - loan.trackDate);
        if (newTrackDate > loan.trackDate) {
            loan.trackDate = newTrackDate;
        }

        loan.freezeDate = 0;

        Loan.Status newStatus = _getStatus(loan);

        if (newStatus != status) {
            emit LoanStatusChanged(loanId, newStatus, status);
        }
    }

    /// @inheritdoc ILendingMarket
    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods)
        external
        whenNotPaused
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }
        if (newDurationInPeriods <= loan.durationInPeriods) {
            revert InappropriateLoanDuration();
        }

        emit LoanDurationUpdated(loanId, newDurationInPeriods, loan.durationInPeriods);

        loan.durationInPeriods = newDurationInPeriods;

        Loan.Status newStatus = _getStatus(loan);

        if (newStatus != status) {
            emit LoanStatusChanged(loanId, newStatus, status);
        }
    }

    /// @inheritdoc ILendingMarket
    function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods)
        external
        whenNotPaused
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }

        uint256 currentDate = calculatePeriodDate(loan.periodInSeconds, 0, 0);
        uint256 currentMoratoriumInPeriods =
            loan.trackDate > currentDate ? (loan.trackDate - currentDate) / loan.periodInSeconds : 0;

        if (newMoratoriumInPeriods <= currentMoratoriumInPeriods) {
            revert InappropriateLoanMoratorium();
        }

        emit LoanMoratoriumUpdated(loanId, newMoratoriumInPeriods, currentMoratoriumInPeriods);

        loan.trackDate += newMoratoriumInPeriods * loan.periodInSeconds;

        Loan.Status newStatus = _getStatus(loan);

        if (newStatus != status) {
            emit LoanStatusChanged(loanId, newStatus, status);
        }
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate)
        external
        whenNotPaused
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }
        if (newInterestRate >= loan.interestRatePrimary) {
            revert InappropriateInterestRate();
        }

        emit LoanInterestRatePrimaryUpdated(loanId, newInterestRate, loan.interestRatePrimary);

        loan.interestRatePrimary = newInterestRate;
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate)
        external
        whenNotPaused
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }
        if (newInterestRate >= loan.interestRateSecondary) {
            revert InappropriateInterestRate();
        }

        emit LoanInterestRateSecondaryUpdated(loanId, newInterestRate, loan.interestRateSecondary);

        loan.interestRateSecondary = newInterestRate;
    }

    /// @inheritdoc ILendingMarket
    function updateLender(address creditLine, address newLender) external {
        /**
         * TBD
         * Updating the lender results in a different liquidity pool.
         * Understand all the side effects of this operation.
         */

        revert Error.NotImplemented();
    }

    /************************************************
     *  VIEW FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function getLender(address creditLine) external view returns (address) {
        return _creditLines[creditLine];
    }

    /// @inheritdoc ILendingMarket
    function getLiquidityPool(address lender) external view returns (address) {
        return _liquidityPools[lender];
    }

    /// @inheritdoc ILendingMarket
    function getLoanStored(uint256 loanId) external view returns (Loan.State memory) {
        return _loans[loanId];
    }

    /// @inheritdoc ILendingMarket
    function getLoanCurrent(uint256 loanId) external view returns (Loan.Status, Loan.State memory) {
        Loan.State storage loanState = _loans[loanId];
        Loan.Status loanStatus = _getStatus(loanState);
        return (loanStatus, _loans[loanId]);
    }

    /// @notice Calculates the period date based on the current timestamp
    /// @param periodInSeconds The duration of the period in seconds
    /// @param extraPeriods The number of extra periods to add
    /// @param extraSeconds The number of extra seconds to add
    function calculatePeriodDate(uint256 periodInSeconds, uint256 extraPeriods, uint256 extraSeconds)
        public
        view
        returns (uint256)
    {
        return (block.timestamp / periodInSeconds) * periodInSeconds + periodInSeconds * extraPeriods + extraSeconds;
    }

    /// @notice Calculates the outstanding balance of a loan
    /// @param originalBalance The original balance of the loan
    /// @param numberOfPeriods The number of periods since the loan was taken
    /// @param interestRate The interest rate of the loan (in basis points)
    /// @param interestRateFactor The interest rate factor used with interest rate
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) public pure returns (uint256) {
        return InterestMath.calculateOutstandingBalance(
            originalBalance, numberOfPeriods, interestRate, interestRateFactor, interestFormula
        );
    }

    /************************************************
     *  INTERNAL FUNCTIONS
     ***********************************************/

    /// @notice Registers a new credit line
    /// @param lender The address of the credit line lender
    /// @param creditLine The address of the credit line contract
    function _registerCreditLine(address lender, address creditLine) internal {
        if (lender == address(0)) {
            revert Error.InvalidAddress();
        }
        if (creditLine == address(0)) {
            revert Error.InvalidAddress();
        }
        if (_creditLines[creditLine] != address(0)) {
            revert CreditLineAlreadyRegistered();
        }

        _creditLines[creditLine] = lender;

        emit CreditLineRegistered(lender, creditLine);
    }

    /// @notice Registers a new liquidity pool
    /// @param lender The address of the liquidity pool lender
    /// @param liquidityPool The address of the liquidity pool contract
    function _registerLiquidityPool(address lender, address liquidityPool) internal {
        if (lender == address(0)) {
            revert Error.InvalidAddress();
        }
        if (liquidityPool == address(0)) {
            revert Error.InvalidAddress();
        }
        if (_liquidityPools[lender] != address(0)) {
            revert LiquidityPoolAlreadyRegistered();
        }

        _liquidityPools[lender] = liquidityPool;

        emit LiquidityPoolRegistered(lender, liquidityPool);
    }

    /// @notice Retrieves the status of a loan
    /// @param self The loan state struct to check the status of
    function _getStatus(Loan.State storage self) internal view returns (Loan.Status) {
        if (self.token == address(0)) {
            return Loan.Status.Nonexistent;
        }

        if (self.freezeDate != 0) {
            return Loan.Status.Frozen;
        }

        if (self.trackedBorrowAmount == 0) {
            if (self.trackDate < self.startDate + self.periodInSeconds * self.durationInPeriods) {
                return Loan.Status.Repaid;
            } else {
                return Loan.Status.Recovered;
            }
        } else {
            uint256 currentDate = calculatePeriodDate(self.periodInSeconds, 0, 0);
            if (currentDate < self.startDate + self.periodInSeconds * self.durationInPeriods) {
                return Loan.Status.Active;
            } else {
                return Loan.Status.Defaulted;
            }
        }
    }

    /// @notice Takes a loan
    /// @param borrower The address of the borrower
    /// @param creditLine The address of the credit line contract
    /// @param amount The amount of the loan
    function _takeLoan(address borrower, address creditLine, uint256 amount) internal {
        if (creditLine == address(0)) {
            revert Error.InvalidAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        address lender = _creditLines[creditLine];
        address pool = _liquidityPools[lender];

        if (lender == address(0)) {
            revert CreditLineNotRegistered();
        }
        if (pool == address(0)) {
            revert LiquidityPoolNotRegistered();
        }

        Loan.Terms memory terms = ICreditLine(creditLine).onLoanTaken(borrower, amount);

        uint256 startDate = calculatePeriodDate(terms.periodInSeconds, 0, 0);
        uint256 totalAmount = amount + terms.addonAmount;

        uint256 id = ICapybaraNFT(_nft).safeMint(lender);

        Loan.State memory loan = Loan.State({
            token: terms.token,
            borrower: borrower,
            periodInSeconds: terms.periodInSeconds,
            durationInPeriods: terms.durationInPeriods,
            interestRateFactor: terms.interestRateFactor,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            startDate: startDate,
            freezeDate: 0,
            trackDate: startDate,
            initialBorrowAmount: totalAmount,
            trackedBorrowAmount: totalAmount
        });

        _loans[id] = loan;

        ILiquidityPool(pool).onBeforeLoanTaken(id, creditLine);
        IERC20(terms.token).safeTransferFrom(pool, borrower, amount);
        if (terms.addonAmount != 0) {
            IERC20(terms.token).safeTransferFrom(pool, terms.addonRecipient, terms.addonAmount);
        }
        ILiquidityPool(pool).onAfterLoanTaken(id, creditLine);

        emit LoanTaken(id, borrower, totalAmount);
    }

    /// @notice Repays a loan
    /// @param repayer The address of the repayer
    /// @param loanId The identifier of the loan
    /// @param amount The amount to be repaid
    function _repayLoan(address repayer, uint256 loanId, uint256 amount) internal {
        if (repayer == address(0)) {
            revert Error.InvalidAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        Loan.State storage loan = _loans[loanId];
        Loan.Status status = _getStatus(loan);

        if (status == Loan.Status.Nonexistent) {
            revert LoanNotExist();
        }
        if (status == Loan.Status.Repaid || status == Loan.Status.Recovered) {
            revert InappropriateLoanStatus();
        }

        uint256 outstandingBalance = loan.trackedBorrowAmount;
        uint256 currentDate = loan.freezeDate == 0 ? calculatePeriodDate(loan.periodInSeconds, 0, 0) : loan.freezeDate;

        if (currentDate > loan.trackDate) {
            uint256 dueDate = loan.startDate + loan.durationInPeriods * loan.periodInSeconds;

            if (currentDate < dueDate) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - loan.trackDate) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else if (loan.trackDate >= dueDate) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - loan.trackDate) / loan.periodInSeconds,
                    loan.interestRateSecondary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (dueDate - loan.trackDate) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            }
        }

        loan.trackDate = currentDate;

        if (amount == type(uint256).max) {
            amount = outstandingBalance;
        } else if (amount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        outstandingBalance -= amount;
        loan.trackedBorrowAmount = outstandingBalance;

        address pool = _liquidityPools[IERC721(_nft).ownerOf(loanId)];
        ILiquidityPool(pool).onBeforeLoanPayment(loanId, amount);
        IERC20(loan.token).transferFrom(repayer, pool, amount);
        ILiquidityPool(pool).onAfterLoanPayment(loanId, amount);

        emit LoanRepayment(loanId, repayer, loan.borrower, amount, outstandingBalance);

        if (outstandingBalance == 0) {
            IERC721(_nft).safeTransferFrom(IERC721(_nft).ownerOf(loanId), loan.borrower, loanId);
            emit LoanRepaid(loanId, loan.borrower);
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

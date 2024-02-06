// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {Loan} from "./libraries/Loan.sol";
import {Error} from "./libraries/Error.sol";
import {Interest} from "./libraries/Interest.sol";
import {InterestMath} from "./libraries/InterestMath.sol";

import {LendingMarketStorage} from "./LendingMarketStorage.sol";
import {ILendingMarket} from "./interfaces/core/ILendingMarket.sol";
import {ILiquidityPool} from "./interfaces/core/ILiquidityPool.sol";
import {ICreditLine} from "./interfaces/core/ICreditLine.sol";
import {SafeCast} from "./libraries/SafeCast.sol";

/// @title LendingMarket contract
/// @notice Implementation of the lending market contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarket is
    LendingMarketStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ILendingMarket
{
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the loan does not exist
    error LoanNotExist();

    /// @notice Thrown when the loan does not frozen
    error LoanNotFrozen();

    /// @notice Thrown when the loan is already repaid
    error LoanAlreadyRepaid();

    /// @notice Thrown when the loan is already frozen
    error LoanAlreadyFrozen();

    /// @notice Thrown when the credit line is not registered
    error CreditLineNotRegistered();

    /// @notice Thrown when the liquidity pool is not registered
    error LiquidityPoolNotRegistered();

    /// @notice Thrown when the credit line is already registered
    error CreditLineAlreadyRegistered();

    /// @notice Thrown when the liquidity pool is already registered
    error LiquidityPoolAlreadyRegistered();

    /// @notice Thrown when provided with an inappropriate interest rate
    error InappropriateInterestRate();

    /// @notice Thrown when provided with an inappropriate loan duration
    error InappropriateLoanDuration();

    /// @notice Thrown when provided with an inappropriate loan moratorium
    error InappropriateLoanMoratorium();

    /// @notice Thrown when liquidity pool tries to repay a loan without autorepayment
    error AutoRepaymentNotAllowed();

    /************************************************
     *  Modifiers
     ***********************************************/

    /// @notice Throws if called by any account other than the registry
    modifier onlyRegistryOrOwner() {
        if (msg.sender != _registry && msg.sender != owner()) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the loan holder
    /// @param loanId The unique identifier of the loan to check
    modifier onlyLoanHolder(uint256 loanId) {
        if (ownerOf(loanId) != msg.sender) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if the loan does not exist or is already repaid
    /// @param loanId The unique identifier of the loan to check
    modifier onlyOngoingLoan(uint256 loanId) {
        if (_loans[loanId].token == address(0)) {
            revert LoanNotExist();
        }
        if (_loans[loanId].trackedBorrowAmount == 0) {
            revert LoanAlreadyRepaid();
        }
        _;
    }

    /************************************************
     *  Initializers
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param name_ The name of the NFT token that will represent the loans
    /// @param symbol_ The symbol of the NFT token that will represent the loans
    function initialize(string memory name_, string memory symbol_) external initializer {
        __LendingMarket_init(name_, symbol_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param name_ The name of the NFT token that will represent the loans
    /// @param symbol_ The symbol of the NFT token that will represent the loans
    function __LendingMarket_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
        __ERC721Enumerable_init_unchained();
        __LendingMarket_init_unchained();
    }

    /// @notice Unchained internal initializer of the upgradable contract
    function __LendingMarket_init_unchained() internal onlyInitializing {}

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

    /// @notice Sets the address of the registry contract
    /// @param newRegistry The address of the new registry contract
    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == _registry) {
            revert Error.AlreadyConfigured();
        }

        emit SetRegistry(newRegistry, _registry);

        _registry = newRegistry;
    }

    /************************************************
     *  Registry functions
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistryOrOwner {
        if (lender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_creditLines[creditLine] != address(0)) {
            revert CreditLineAlreadyRegistered();
        }

        emit RegisterCreditLine(lender, creditLine);

        _creditLines[creditLine] = lender;
    }

    /// @inheritdoc ILendingMarket
    function registerLiquidityPool(address lender, address liquidityPool) external whenNotPaused onlyRegistryOrOwner {
        if (lender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (liquidityPool == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPools[lender] != address(0)) {
            revert LiquidityPoolAlreadyRegistered();
        }

        emit RegisterLiquidityPool(lender, liquidityPool);

        _liquidityPools[lender] = liquidityPool;
    }

    /************************************************
     *  Borrower functions
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function takeLoan(address creditLine, uint256 amount) external whenNotPaused returns (uint256) {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
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

        uint256 id = _safeMint(lender);
        Loan.Terms memory terms = ICreditLine(creditLine).onBeforeLoanTaken(msg.sender, amount, id);
        uint256 startDate = calculatePeriodDate(block.timestamp, terms.periodInSeconds, 0, 0);
        uint256 totalAmount = amount + uint256(terms.addonAmount);

        Loan.State memory loan = Loan.State({
            token: terms.token,
            borrower: msg.sender,
            periodInSeconds: terms.periodInSeconds,
            durationInPeriods: terms.durationInPeriods,
            interestRateFactor: terms.interestRateFactor,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            startDate: startDate.toUint32(),
            freezeDate: 0,
            trackDate: startDate.toUint32(),
            initialBorrowAmount: totalAmount.toUint64(),
            trackedBorrowAmount: totalAmount.toUint64(),
            autoRepayment: terms.autoRepayment
        });

        _loans[id] = loan;

        ILiquidityPool(pool).onBeforeLoanTaken(id, creditLine);
        IERC20(terms.token).safeTransferFrom(pool, msg.sender, amount);
        if (terms.addonAmount != 0) {
            IERC20(terms.token).safeTransferFrom(pool, terms.addonRecipient, terms.addonAmount);
        }
        ILiquidityPool(pool).onAfterLoanTaken(id, creditLine);

        emit TakeLoan(id, msg.sender, totalAmount);

        return id;
    }

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 amount) external whenNotPaused onlyOngoingLoan(loanId) {
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        Loan.State storage loan = _loans[loanId];

        if (ifLiqudityPool(loanId) && !loan.autoRepayment) {
            revert AutoRepaymentNotAllowed();
        }

        (uint256 outstandingBalance, uint256 currentDate) = _outstandingBalance(loan, block.timestamp);

        if (amount == type(uint256).max) {
            amount = outstandingBalance;
        } else if (amount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        outstandingBalance -= amount;
        loan.trackedBorrowAmount = outstandingBalance.toUint64();
        loan.trackDate = currentDate.toUint32();
        address pool = _liquidityPools[ownerOf(loanId)];
        ILiquidityPool(pool).onBeforeLoanPayment(loanId, amount);
        transferRepayment(loanId, loan, pool, amount);
        ILiquidityPool(pool).onAfterLoanPayment(loanId, amount);

        emit RepayLoan(loanId, msg.sender, loan.borrower, amount, outstandingBalance);

        if (outstandingBalance == 0) {
            _safeTransfer(ownerOf(loanId), loan.borrower, loanId, "");
        }
    }

    /// @notice Transfer the repayment amount to the liquidity pool
    /// @param loanId The unique identifier of the loan to check
    /// @param loan The loan state
    /// @param pool The address of the liquidity pool
    /// @param amount The amount to be transferred
    function transferRepayment(uint256 loanId, Loan.State storage loan, address pool, uint256 amount) internal {
        if (ifLiqudityPool(loanId)) {
            IERC20(loan.token).transferFrom(loan.borrower, pool, amount);
        } else {
            IERC20(loan.token).transferFrom(msg.sender, pool, amount);
        }
    }

    /// @notice Check if the sender is the liquidity pool of the loan
    /// @param loanId The unique identifier of the loan to check
    function ifLiqudityPool(uint256 loanId) internal returns (bool) {
        if (msg.sender == _liquidityPools[ownerOf(loanId)]) {
            return true;
        }

        return false;
    }

    /************************************************
     *  Loan holder functions
     ***********************************************/

    /// @inheritdoc ILendingMarket
    function freeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLoanHolder(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeDate != 0) {
            revert LoanAlreadyFrozen();
        }

        loan.freezeDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0).toUint32();

        emit FreezeLoan(loanId, loan.freezeDate);
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLoanHolder(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeDate == 0) {
            revert LoanNotFrozen();
        }

        uint256 currentDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        uint256 frozenPeriods = (currentDate - loan.freezeDate) / loan.periodInSeconds;

        if (frozenPeriods > 0) {
            loan.trackDate = (uint256(loan.trackDate) + (frozenPeriods * uint256(loan.periodInSeconds))).toUint32();
            loan.durationInPeriods = (uint256(loan.durationInPeriods) + frozenPeriods).toUint32();
        }

        loan.freezeDate = 0;

        emit UnfreezeLoan(loanId, currentDate);
    }

    /// @inheritdoc ILendingMarket
    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods)
        external
        whenNotPaused
        onlyOngoingLoan(loanId)
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];

        if (newDurationInPeriods <= loan.durationInPeriods) {
            revert InappropriateLoanDuration();
        }

        emit UpdateLoanDuration(loanId, newDurationInPeriods, loan.durationInPeriods);

        loan.durationInPeriods = newDurationInPeriods.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods)
        external
        whenNotPaused
        onlyOngoingLoan(loanId)
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];

        uint256 currentDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        uint256 currentMoratoriumInPeriods = 0;
        if (loan.trackDate > currentDate) {
            currentMoratoriumInPeriods = (uint256(loan.trackDate) - currentDate) / uint256(loan.periodInSeconds);
        }

        if (newMoratoriumInPeriods <= currentMoratoriumInPeriods) {
            revert InappropriateLoanMoratorium();
        }

        emit UpdateLoanMoratorium(loanId, loan.trackDate, newMoratoriumInPeriods);

        loan.trackDate += (newMoratoriumInPeriods * uint256(loan.periodInSeconds)).toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate)
        external
        whenNotPaused
        onlyOngoingLoan(loanId)
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];

        if (newInterestRate >= loan.interestRatePrimary) {
            revert InappropriateInterestRate();
        }

        emit UpdateLoanInterestRatePrimary(loanId, newInterestRate, loan.interestRatePrimary);

        loan.interestRatePrimary = newInterestRate.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate)
        external
        whenNotPaused
        onlyOngoingLoan(loanId)
        onlyLoanHolder(loanId)
    {
        Loan.State storage loan = _loans[loanId];

        if (newInterestRate >= loan.interestRateSecondary) {
            revert InappropriateInterestRate();
        }

        emit UpdateLoanInterestRateSecondary(loanId, newInterestRate, loan.interestRateSecondary);

        loan.interestRateSecondary = newInterestRate.toUint32();
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
     *  View functions
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
    function getLoan(uint256 loanId) external view returns (Loan.State memory) {
        return _loans[loanId];
    }

    /// @inheritdoc ILendingMarket
    function getLoanBalance(uint256 loanId, uint256 timestamp) external view returns (uint256, uint256) {
        if (timestamp == 0) {
            timestamp = block.timestamp;
        }
        return _outstandingBalance(_loans[loanId], timestamp);
    }

    /// @inheritdoc ILendingMarket
    function registry() external view returns (address) {
        return _registry;
    }

    /// @notice Calculates the period date based on the current timestamp
    /// @param timestamp The timestamp to calculate the period date from
    /// @param periodInSeconds The duration of the period in seconds
    /// @param extraPeriods The number of extra periods to add
    /// @param extraSeconds The number of extra seconds to add
    function calculatePeriodDate(
        uint256 timestamp,
        uint256 periodInSeconds,
        uint256 extraPeriods,
        uint256 extraSeconds
    ) public pure returns (uint256) {
        return (timestamp / periodInSeconds) * periodInSeconds + periodInSeconds * extraPeriods + extraSeconds;
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
     *  Internal functions
     ***********************************************/

    /// @notice Calculates the outstanding balance of a loan and the current date
    function _outstandingBalance(Loan.State storage loan, uint256 timestamp) internal view returns (uint256, uint256) {
        uint256 outstandingBalance = loan.trackedBorrowAmount;

        uint256 currentDate = calculatePeriodDate(timestamp, loan.periodInSeconds, 0, 0);
        if (loan.freezeDate != 0) {
            currentDate = loan.freezeDate;
        }

        if (currentDate > loan.trackDate) {
            uint256 dueDate = uint256(loan.startDate) + uint256(loan.durationInPeriods) * uint256(loan.periodInSeconds);

            if (currentDate < dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - uint256(loan.trackDate)) / uint256(loan.periodInSeconds),
                    uint256(loan.interestRatePrimary),
                    uint256(loan.interestRateFactor),
                    loan.interestFormula
                );
            } else if (loan.trackDate >= dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - uint256(loan.trackDate)) / uint256(loan.periodInSeconds),
                    uint256(loan.interestRateSecondary),
                    uint256(loan.interestRateFactor),
                    loan.interestFormula
                );
            } else {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (dueDate - uint256(loan.trackDate)) / uint256(loan.periodInSeconds),
                    uint256(loan.interestRatePrimary),
                    uint256(loan.interestRateFactor),
                    loan.interestFormula
                );
            }
        }

        return (outstandingBalance, currentDate);
    }

    /// @notice Creates a new NFT token and mints it to the lender
    function _safeMint(address to) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /************************************************
     *  ERC721 functions
     ***********************************************/

    /// @inheritdoc ERC721Upgradeable
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @inheritdoc ERC721Upgradeable
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._increaseBalance(account, value);
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

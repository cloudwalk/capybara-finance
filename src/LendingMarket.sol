// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import { Loan } from "./libraries/Loan.sol";
import { Error } from "./libraries/Error.sol";
import { Interest } from "./libraries/Interest.sol";
import { InterestMath } from "./libraries/InterestMath.sol";
import { SafeCast } from "./libraries/SafeCast.sol";

import { ILendingMarket } from "./interfaces/core/ILendingMarket.sol";
import { ILiquidityPool } from "./interfaces/core/ILiquidityPool.sol";
import { ICreditLine } from "./interfaces/core/ICreditLine.sol";

import { LendingMarketStorage } from "./LendingMarketStorage.sol";

/// @title LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Implementation of the lending market contract.
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

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the loan does not exist.
    error LoanNotExist();

    /// @notice Thrown when the loan is not frozen.
    error LoanNotFrozen();

    /// @notice Thrown when the loan is already repaid.
    error LoanAlreadyRepaid();

    /// @notice Thrown when the loan is already frozen.
    error LoanAlreadyFrozen();

    /// @notice Thrown when the credit line is not registered.
    error CreditLineNotRegistered();

    /// @notice Thrown when the liquidity pool is not registered.
    error LiquidityPoolNotRegistered();

    /// @notice Thrown when the credit line is already registered.
    error CreditLineAlreadyRegistered();

    /// @notice Thrown when the liquidity pool is already registered.
    error LiquidityPoolAlreadyRegistered();

    /// @notice Thrown when provided interest rate is inappropriate.
    error InappropriateInterestRate();

    /// @notice Thrown when provided loan duration is inappropriate.
    error InappropriateLoanDuration();

    /// @notice Thrown when provided loan moratorium is inappropriate.
    error InappropriateLoanMoratorium();

    /// @notice Thrown when loan auto repayment is not allowed.
    error AutoRepaymentNotAllowed();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @notice Throws if called by any account other than the market registry or the owner.
    modifier onlyRegistryOrOwner() {
        if (msg.sender != _registry && msg.sender != owner()) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the lender or its alias.
    /// @param loanId The unique identifier of the loan to check.
    modifier onlyLenderOrAlias(uint256 loanId) {
        address lender = ownerOf(loanId);
        if (msg.sender != lender && _hasAlias[lender][msg.sender] == false) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if the loan does not exist or has already been repaid.
    /// @param loanId The unique identifier of the loan to check.
    modifier onlyOngoingLoan(uint256 loanId) {
        if (_loans[loanId].token == address(0)) {
            revert LoanNotExist();
        }
        if (_loans[loanId].trackedBorrowBalance == 0) {
            revert LoanAlreadyRepaid();
        }
        _;
    }

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @notice Initializer of the upgradable contract.
    /// @param name_ The name of the NFT token that will represent the loans.
    /// @param symbol_ The symbol of the NFT token that will represent the loans.
    function initialize(string memory name_, string memory symbol_) external initializer {
        __LendingMarket_init(name_, symbol_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param name_ The name of the NFT token that will represent the loans.
    /// @param symbol_ The symbol of the NFT token that will represent the loans.
    function __LendingMarket_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
        __ERC721Enumerable_init_unchained();
        __LendingMarket_init_unchained();
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    function __LendingMarket_init_unchained() internal onlyInitializing { }

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

    /// @notice Sets the address of the lending market registry.
    /// @param newRegistry The address of the new registry.
    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == _registry) {
            revert Error.AlreadyConfigured();
        }

        emit MarketRegistryChanged(newRegistry, _registry);

        _registry = newRegistry;
    }

    // -------------------------------------------- //
    //  Registry functions                          //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistryOrOwner {
        if (lender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_creditLineLenders[creditLine] != address(0)) {
            revert CreditLineAlreadyRegistered();
        }

        emit CreditLineRegistered(lender, creditLine);

        _creditLineLenders[creditLine] = lender;
    }

    /// @inheritdoc ILendingMarket
    function registerLiquidityPool(address lender, address liquidityPool) external whenNotPaused onlyRegistryOrOwner {
        if (lender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (liquidityPool == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPoolLenders[liquidityPool] != address(0)) {
            revert LiquidityPoolAlreadyRegistered();
        }

        emit LiquidityPoolRegistered(lender, liquidityPool);

        _liquidityPoolLenders[liquidityPool] = lender;
    }

    /// @inheritdoc ILendingMarket
    function updateCreditLineLender(address creditLine, address newLender) external {
        // TBD Check if updating the lender associated with the credit line
        // can have any unexpected side effects during the loan lifecycle.
        revert Error.NotImplemented();
    }

    function updateLiquidityPoolLender(address liquidityPool, address newLender) external {
        // TBD Check if updating the lender associated with the liquidity pool
        // can have any unexpected side effects during the loan lifecycle.
        revert Error.NotImplemented();
    }

    /// @inheritdoc ILendingMarket
    function assignLiquidityPoolToCreditLine(address creditLine, address liquidityPool) external whenNotPaused {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (liquidityPool == address(0)) {
            revert Error.ZeroAddress();
        }

        if (_liquidityPoolByCreditLine[creditLine] != address(0)) {
            // TBD Check if updating the liquidity pool associated with the credit line
            // can have any unexpected side effects during the loan lifecycle.
            revert Error.NotImplemented();
        }

        if (_creditLineLenders[creditLine] != msg.sender || _liquidityPoolLenders[liquidityPool] != msg.sender) {
            revert Error.Unauthorized();
        }

        emit LiquidityPoolAssignedToCreditLine(creditLine, liquidityPool, _liquidityPoolByCreditLine[creditLine]);

        _liquidityPoolByCreditLine[creditLine] = liquidityPool;
    }

    // -------------------------------------------- //
    //  Borrower functions                          //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function takeLoan(
        address creditLine,
        uint256 borrowAmount,
        uint256 durationInPeriods
    ) external whenNotPaused returns (uint256) {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (borrowAmount == 0) {
            revert Error.InvalidAmount();
        }

        address lender = _creditLineLenders[creditLine];
        address liquidityPool = _liquidityPoolByCreditLine[creditLine];

        if (lender == address(0)) {
            revert CreditLineNotRegistered();
        }
        if (liquidityPool == address(0)) {
            revert LiquidityPoolNotRegistered();
        }

        uint256 id = _safeMint(lender);
        Loan.Terms memory terms =
            ICreditLine(creditLine).onBeforeLoanTaken(msg.sender, borrowAmount, durationInPeriods, id);
        uint256 totalAmount = borrowAmount + terms.addonAmount;

        _loans[id] = Loan.State({
            token: terms.token,
            borrower: msg.sender,
            treasury: terms.treasury,
            startTimestamp: _blockTimestamp().toUint32(),
            periodInSeconds: terms.periodInSeconds,
            durationInPeriods: terms.durationInPeriods,
            interestRateFactor: terms.interestRateFactor,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            initialBorrowAmount: totalAmount.toUint64(),
            trackedBorrowBalance: totalAmount.toUint64(),
            trackedTimestamp: _blockTimestamp().toUint32(),
            freezeTimestamp: 0,
            autoRepayment: terms.autoRepayment
        });

        ILiquidityPool(liquidityPool).onBeforeLoanTaken(id, creditLine);

        IERC20(terms.token).safeTransferFrom(liquidityPool, msg.sender, borrowAmount);
        if (terms.addonAmount != 0) {
            IERC20(terms.token).safeTransferFrom(liquidityPool, terms.addonRecipient, terms.addonAmount);
        }

        ILiquidityPool(liquidityPool).onAfterLoanTaken(id, creditLine);

        emit LoanTaken(id, msg.sender, totalAmount);

        return id;
    }

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 repayAmount) external whenNotPaused onlyOngoingLoan(loanId) {
        if (repayAmount == 0) {
            revert Error.InvalidAmount();
        }

        Loan.State storage loan = _loans[loanId];

        if (loan.treasury.code.length == 0) {
            // TBD Add support for EOA liquidity pools.
            revert Error.NotImplemented();
        }

        uint256 outstandingBalance = _outstandingBalance(loan, _blockTimestamp());

        if (repayAmount == type(uint256).max) {
            repayAmount = outstandingBalance;
        } else if (repayAmount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        bool autoRepayment = loan.treasury == msg.sender;

        if (autoRepayment && !loan.autoRepayment) {
            revert AutoRepaymentNotAllowed();
        }

        address payer = autoRepayment ? loan.borrower : msg.sender;

        outstandingBalance -= repayAmount;
        loan.trackedTimestamp = _blockTimestamp().toUint32();
        loan.trackedBorrowBalance = outstandingBalance.toUint64();

        ILiquidityPool(loan.treasury).onBeforeLoanPayment(loanId, repayAmount);
        IERC20(loan.token).transferFrom(payer, loan.treasury, repayAmount);
        ILiquidityPool(loan.treasury).onAfterLoanPayment(loanId, repayAmount);

        emit LoanPaid(loanId, payer, loan.borrower, repayAmount, outstandingBalance);

        if (outstandingBalance == 0) {
            _safeTransfer(ownerOf(loanId), loan.borrower, loanId, "");
        }
    }

    // -------------------------------------------- //
    //  Lender functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function freeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeTimestamp != 0) {
            revert LoanAlreadyFrozen();
        }

        loan.freezeTimestamp = _blockTimestamp().toUint32();

        emit LoanFrozen(loanId, _blockTimestamp());
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeTimestamp == 0) {
            revert LoanNotFrozen();
        }

        uint256 currentPeriod = _periodIndex(_blockTimestamp(), loan.periodInSeconds);
        uint256 freezePeriod = _periodIndex(loan.freezeTimestamp, loan.periodInSeconds);
        uint256 skipPeriods = (currentPeriod - freezePeriod) / loan.periodInSeconds;

        if (skipPeriods > 0) {
            loan.trackedTimestamp += (skipPeriods * loan.periodInSeconds).toUint32();
            loan.durationInPeriods += skipPeriods.toUint32();
        }

        loan.freezeTimestamp = 0;

        emit LoanUnfrozen(loanId, _blockTimestamp());
    }

    /// @inheritdoc ILendingMarket
    function updateLoanDuration(
        uint256 loanId,
        uint256 newDurationInPeriods
    ) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (newDurationInPeriods <= loan.durationInPeriods) {
            revert InappropriateLoanDuration();
        }

        emit LoanDurationUpdated(loanId, newDurationInPeriods, loan.durationInPeriods);

        loan.durationInPeriods = newDurationInPeriods.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanMoratorium(
        uint256 loanId,
        uint256 newMoratoriumInPeriods
    ) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        uint256 currentMoratoriumInPeriods = _moratoriumInPeriods(loan, _blockTimestamp());
        if (newMoratoriumInPeriods <= currentMoratoriumInPeriods) {
            revert InappropriateLoanMoratorium();
        }

        newMoratoriumInPeriods -= currentMoratoriumInPeriods;

        emit LoanMoratoriumUpdated(loanId, loan.trackedTimestamp, newMoratoriumInPeriods);

        loan.trackedTimestamp += (newMoratoriumInPeriods * loan.periodInSeconds).toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRatePrimary(
        uint256 loanId,
        uint256 newInterestRate
    ) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (newInterestRate >= loan.interestRatePrimary) {
            revert InappropriateInterestRate();
        }

        emit LoanInterestRatePrimaryUpdated(loanId, newInterestRate, loan.interestRatePrimary);

        loan.interestRatePrimary = newInterestRate.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRateSecondary(
        uint256 loanId,
        uint256 newInterestRate
    ) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (newInterestRate >= loan.interestRateSecondary) {
            revert InappropriateInterestRate();
        }

        emit LoanInterestRateSecondaryUpdated(loanId, newInterestRate, loan.interestRateSecondary);

        loan.interestRateSecondary = newInterestRate.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function configureAlias(address account, bool isAlias) external whenNotPaused {
        if (account == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_hasAlias[msg.sender][account] == isAlias) {
            revert Error.AlreadyConfigured();
        }

        emit LenderAliasConfigured(msg.sender, account, isAlias);

        _hasAlias[msg.sender][account] = isAlias;
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function getCreditLineLender(address creditLine) external view returns (address) {
        return _creditLineLenders[creditLine];
    }

    /// @inheritdoc ILendingMarket
    function getLiquidityPoolLender(address liquidityPool) external view returns (address) {
        return _liquidityPoolLenders[liquidityPool];
    }

    /// @inheritdoc ILendingMarket
    function getLiquidityPoolByCreditLine(address creditLine) external view returns (address) {
        return _liquidityPoolByCreditLine[creditLine];
    }

    /// @inheritdoc ILendingMarket
    function getLoanState(uint256 loanId) external view returns (Loan.State memory) {
        return _loans[loanId];
    }

    /// @inheritdoc ILendingMarket
    function getLoanPreview(uint256 loanId, uint256 timestamp) external view returns (Loan.Preview memory) {
        if (timestamp == 0) {
            timestamp = _blockTimestamp();
        }

        Loan.Preview memory preview;
        Loan.State storage loan = _loans[loanId];

        preview.outstandingBalance = _outstandingBalance(loan, timestamp);
        preview.periodIndex = _periodIndex(timestamp, loan.periodInSeconds);

        return preview;
    }

    /// @inheritdoc ILendingMarket
    function hasAlias(address lender, address account) external view returns (bool) {
        return _hasAlias[lender][account];
    }

    /// @inheritdoc ILendingMarket
    function registry() external view returns (address) {
        return _registry;
    }

    /// @notice Calculates the period index based on the provided timestamp.
    /// @param timestamp The timestamp to calculate the period index for.
    /// @param periodInSeconds The period duration in seconds.
    function calculatePeriodIndex(uint256 timestamp, uint256 periodInSeconds) external pure returns (uint256) {
        return _periodIndex(timestamp, periodInSeconds);
    }

    /// @notice Calculates the outstanding balance of a loan.
    /// @param originalBalance The balance of the loan at the beginning.
    /// @param numberOfPeriods The number of periods to calculate the outstanding balance.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor The interest rate factor.
    /// @param interestFormula The interest formula.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor,
        Interest.Formula interestFormula
    ) external pure returns (uint256) {
        return InterestMath.calculateOutstandingBalance(
            originalBalance, numberOfPeriods, interestRate, interestRateFactor, interestFormula
        );
    }

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan.
    /// @param loan The loan to calculate the outstanding balance for.
    /// @param timestamp The timestamp to calculate the outstanding balance at.
    /// @return The outstanding balance of the loan at the specified period date.
    function _outstandingBalance(Loan.State storage loan, uint256 timestamp) internal view returns (uint256) {
        uint256 outstandingBalance = loan.trackedBorrowBalance;

        if (loan.freezeTimestamp != 0) {
            timestamp = loan.freezeTimestamp;
        }

        uint256 currentPeriod = _periodIndex(timestamp, loan.periodInSeconds);
        uint256 trackedPeriod = _periodIndex(loan.trackedTimestamp, loan.periodInSeconds);

        if (currentPeriod > trackedPeriod) {
            uint256 startPeriod = _periodIndex(loan.startTimestamp, loan.periodInSeconds);
            uint256 duePeriod = startPeriod + loan.durationInPeriods * loan.periodInSeconds;

            if (currentPeriod < duePeriod) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (currentPeriod - trackedPeriod) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else if (trackedPeriod >= duePeriod) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (currentPeriod - trackedPeriod) / loan.periodInSeconds,
                    loan.interestRateSecondary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    (duePeriod - trackedPeriod) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
                if (currentPeriod > duePeriod) {
                    outstandingBalance = InterestMath.calculateOutstandingBalance(
                        outstandingBalance,
                        (currentPeriod - duePeriod) / loan.periodInSeconds,
                        loan.interestRateSecondary,
                        loan.interestRateFactor,
                        loan.interestFormula
                    );
                }
            }
        }

        return outstandingBalance;
    }

    /// @dev Calculates the moratorium periods of a loan.
    /// @param loan The loan to calculate the moratorium periods for.
    /// @param timestamp The timestamp to calculate the moratorium periods at.
    /// @return The number of moratorium periods of the loan at the specified timestamp.
    function _moratoriumInPeriods(Loan.State storage loan, uint256 timestamp) internal view returns (uint256) {
        uint256 currentPeriod = _periodIndex(timestamp, loan.periodInSeconds);
        uint256 trackedPeriod = _periodIndex(loan.trackedTimestamp, loan.periodInSeconds);
        return trackedPeriod > currentPeriod ? (trackedPeriod - currentPeriod) / loan.periodInSeconds : 0;
    }

    /// @dev Mints a new NFT token.
    /// @param to The address to mint the token to.
    /// @return The unique identifier of the minted token.
    function _safeMint(address to) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /// @dev Calculates the index of the period for the specified timestamp.
    function _periodIndex(uint256 timestamp, uint256 periodInSeconds) internal pure returns (uint256) {
        return (timestamp / periodInSeconds) * periodInSeconds;
    }

    /// @dev Returns the current block timestamp.
    function _blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    // -------------------------------------------- //
    //  ERC721 functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ERC721Upgradeable
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override (ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }

    /// @inheritdoc ERC721Upgradeable
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override (ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused {
        super._increaseBalance(account, value);
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

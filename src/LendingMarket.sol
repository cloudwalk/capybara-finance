// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { ERC721EnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

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
        if (_loans[loanId].trackedBorrowAmount == 0) {
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

        emit SetRegistry(newRegistry, _registry);

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

        emit RegisterCreditLine(lender, creditLine);

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

        emit RegisterLiquidityPool(lender, liquidityPool);

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

        emit AssignLiquidityPoolToCreditLine(creditLine, liquidityPool, _liquidityPoolByCreditLine[creditLine]);

        _liquidityPoolByCreditLine[creditLine] = liquidityPool;
    }

    // -------------------------------------------- //
    //  Borrower functions                          //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function takeLoan(address creditLine, uint256 borrowAmount) external whenNotPaused returns (uint256) {
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
        Loan.Terms memory terms = ICreditLine(creditLine).onBeforeLoanTaken(msg.sender, borrowAmount, id);
        uint256 startDate = calculatePeriodDate(block.timestamp, terms.periodInSeconds, 0, 0);
        uint256 totalAmount = borrowAmount + terms.addonAmount;

        _loans[id] = Loan.State({
            token: terms.token,
            holder: terms.holder,
            borrower: msg.sender,
            startDate: startDate.toUint32(),
            periodInSeconds: terms.periodInSeconds,
            durationInPeriods: terms.durationInPeriods,
            interestRateFactor: terms.interestRateFactor,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            initialBorrowAmount: totalAmount.toUint64(),
            trackedBorrowAmount: totalAmount.toUint64(),
            trackedDate: startDate.toUint32(),
            freezeDate: 0,
            autoRepayment: terms.autoRepayment
        });

        ILiquidityPool(liquidityPool).onBeforeLoanTaken(id, creditLine);

        IERC20(terms.token).safeTransferFrom(liquidityPool, msg.sender, borrowAmount);
        if (terms.addonAmount != 0) {
            IERC20(terms.token).safeTransferFrom(liquidityPool, terms.addonRecipient, terms.addonAmount);
        }

        ILiquidityPool(liquidityPool).onAfterLoanTaken(id, creditLine);

        emit TakeLoan(id, msg.sender, totalAmount);

        return id;
    }

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 repayAmount) external whenNotPaused onlyOngoingLoan(loanId) {
        if (repayAmount == 0) {
            revert Error.InvalidAmount();
        }

        Loan.State storage loan = _loans[loanId];

        if (loan.holder.code.length == 0) {
            // TBD Add support for EOA liquidity pools.
            revert Error.NotImplemented();
        }

        uint256 currentDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        uint256 outstandingBalance = _outstandingBalance(loan, currentDate);

        if (repayAmount == type(uint256).max) {
            repayAmount = outstandingBalance;
        } else if (repayAmount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        bool autoRepayment = loan.holder == msg.sender;

        if (autoRepayment && !loan.autoRepayment) {
            revert AutoRepaymentNotAllowed();
        }

        address payer = autoRepayment ? loan.borrower : msg.sender;

        outstandingBalance -= repayAmount;
        loan.trackedBorrowAmount = outstandingBalance.toUint64();
        loan.trackedDate = currentDate.toUint32();

        ILiquidityPool(loan.holder).onBeforeLoanPayment(loanId, repayAmount);
        IERC20(loan.token).transferFrom(payer, loan.holder, repayAmount);
        ILiquidityPool(loan.holder).onAfterLoanPayment(loanId, repayAmount);

        emit RepayLoan(loanId, payer, loan.borrower, repayAmount, outstandingBalance);

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

        if (loan.freezeDate != 0) {
            revert LoanAlreadyFrozen();
        }

        loan.freezeDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0).toUint32();

        emit FreezeLoan(loanId, loan.freezeDate);
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeDate == 0) {
            revert LoanNotFrozen();
        }

        uint256 currentDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        uint256 frozenPeriods = (currentDate - loan.freezeDate) / loan.periodInSeconds;

        if (frozenPeriods > 0) {
            loan.trackedDate += (frozenPeriods * loan.periodInSeconds).toUint32();
            loan.durationInPeriods += frozenPeriods.toUint32();
        }

        loan.freezeDate = 0;

        emit UnfreezeLoan(loanId, currentDate);
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

        emit UpdateLoanDuration(loanId, newDurationInPeriods, loan.durationInPeriods);

        loan.durationInPeriods = newDurationInPeriods.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanMoratorium(
        uint256 loanId,
        uint256 newMoratoriumInPeriods
    ) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        uint256 currentMoratoriumInPeriods = _moratoriumInPeriods(loan, block.timestamp);
        if (newMoratoriumInPeriods <= currentMoratoriumInPeriods) {
            revert InappropriateLoanMoratorium();
        }

        newMoratoriumInPeriods -= currentMoratoriumInPeriods;

        emit UpdateLoanMoratorium(loanId, loan.trackedDate, newMoratoriumInPeriods);

        loan.trackedDate += (newMoratoriumInPeriods * loan.periodInSeconds).toUint32();
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

        emit UpdateLoanInterestRatePrimary(loanId, newInterestRate, loan.interestRatePrimary);

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

        emit UpdateLoanInterestRateSecondary(loanId, newInterestRate, loan.interestRateSecondary);

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

        emit ConfigureLenderAlias(msg.sender, account, isAlias);

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
            timestamp = block.timestamp;
        }

        Loan.Preview memory preview;
        Loan.State storage loan = _loans[loanId];

        uint256 currentDate = calculatePeriodDate(timestamp, loan.periodInSeconds, 0, 0);
        preview.outstandingBalance = _outstandingBalance(loan, currentDate);
        preview.periodDate = currentDate;

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

    /// @notice Calculates the period date based on the current timestamp.
    /// @param timestamp The timestamp to calculate the period date for.
    /// @param periodInSeconds The duration of the period in seconds.
    /// @param extraPeriods The number of extra periods to add.
    /// @param extraSeconds The number of extra seconds to add.
    function calculatePeriodDate(
        uint256 timestamp,
        uint256 periodInSeconds,
        uint256 extraPeriods,
        uint256 extraSeconds
    ) public pure returns (uint256) {
        return (timestamp / periodInSeconds) * periodInSeconds + periodInSeconds * extraPeriods + extraSeconds;
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
    ) public pure returns (uint256) {
        return InterestMath.calculateOutstandingBalance(
            originalBalance, numberOfPeriods, interestRate, interestRateFactor, interestFormula
        );
    }

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan.
    /// @param loan The loan to calculate the outstanding balance for.
    /// @param periodDate The period date to calculate the outstanding balance at.
    /// @return The outstanding balance of the loan at the specified period date.
    function _outstandingBalance(Loan.State storage loan, uint256 periodDate) internal view returns (uint256) {
        uint256 outstandingBalance = loan.trackedBorrowAmount;

        if (loan.freezeDate != 0) {
            periodDate = loan.freezeDate;
        }

        if (periodDate > loan.trackedDate) {
            uint256 dueDate = loan.startDate + loan.durationInPeriods * loan.periodInSeconds;

            if (periodDate < dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (periodDate - loan.trackedDate) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else if (loan.trackedDate >= dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (periodDate - loan.trackedDate) / loan.periodInSeconds,
                    loan.interestRateSecondary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (dueDate - loan.trackedDate) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
                if (periodDate > dueDate) {
                    outstandingBalance = calculateOutstandingBalance(
                        outstandingBalance,
                        (periodDate - dueDate) / loan.periodInSeconds,
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
        uint256 currentDate = calculatePeriodDate(timestamp, loan.periodInSeconds, 0, 0);
        return loan.trackedDate > currentDate ? (loan.trackedDate - currentDate) / loan.periodInSeconds : 0;
    }

    /// @dev Mints a new NFT token.
    /// @param to The address to mint the token to.
    /// @return The unique identifier of the minted token.
    function _safeMint(address to) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
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

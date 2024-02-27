// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

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
/// @notice Implementation of the lending market contract
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

    /// @notice Thrown when loan auto repayment is not allowed
    error AutoRepaymentNotAllowed();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @notice Throws if called by any account other than the registry
    modifier onlyRegistryOrOwner() {
        if (msg.sender != _registry && msg.sender != owner()) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the lender or its alias
    /// @param loanId The unique identifier of the loan to check
    modifier onlyLenderOrAlias(uint256 loanId) {
        address lender = ownerOf(loanId);
        if (msg.sender != lender && _hasAlias[lender][msg.sender] == false) {
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

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

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
    function __LendingMarket_init_unchained() internal onlyInitializing { }

    // -------------------------------------------- //
    //  Owner functions                             //
    // -------------------------------------------- //

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
        // can have any unexpected side effects during the loan lifecycle
        revert Error.NotImplemented();
    }

    function updateLiquidityPoolLender(address liquidityPool, address newLender) external {
        // TBD Check if updating the lender associated with the liquidity pool
        // can have any unexpected side effects during the loan lifecycle
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
            // can have any unexpected side effects during the loan lifecycle
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
    function takeLoan(address creditLine, uint256 amount) external whenNotPaused returns (uint256) {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        // Get lender
        address lender = _creditLineLenders[creditLine];

        // Get liquidity pool
        address liquidityPool = _liquidityPoolByCreditLine[creditLine];

        if (lender == address(0)) {
            revert CreditLineNotRegistered();
        }
        if (liquidityPool == address(0)) {
            revert LiquidityPoolNotRegistered();
        }

        // TBD Validate the credit line and the liquidity pool according to the lending market requirements

        // Mint a new NFT token to the lender
        uint256 id = _safeMint(lender);

        // Get the terms of the loan from the credit line
        Loan.Terms memory terms = ICreditLine(creditLine).onBeforeLoanTaken(msg.sender, amount, id);

        // TBD Validate the terms of the loan according to the lending market requirements

        // Calculate the start date and the total amount of the loan
        uint256 startDate = calculatePeriodDate(block.timestamp, terms.periodInSeconds, 0, 0);
        uint256 totalAmount = amount + terms.addonAmount;

        // Create and store the loan state
        _loans[id] = Loan.State({
            token: terms.token,
            holder: terms.holder,
            borrower: msg.sender,
            periodInSeconds: terms.periodInSeconds,
            durationInPeriods: terms.durationInPeriods,
            interestRateFactor: terms.interestRateFactor,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            startDate: startDate.toUint32(),
            freezeDate: 0,
            trackedDate: startDate.toUint32(),
            initialBorrowAmount: totalAmount.toUint64(),
            trackedBorrowAmount: totalAmount.toUint64(),
            autoRepayment: terms.autoRepayment
        });

        // Notify the liquidity pool before the loan is taken
        ILiquidityPool(liquidityPool).onBeforeLoanTaken(id, creditLine);

        // Transfer the loan amount to the borrower
        IERC20(terms.token).safeTransferFrom(liquidityPool, msg.sender, amount);

        // Transfer the addon amount to the addon recipient
        if (terms.addonAmount != 0) {
            IERC20(terms.token).safeTransferFrom(liquidityPool, terms.addonRecipient, terms.addonAmount);
        }

        // Notify the liquidity pool after the loan is taken
        ILiquidityPool(liquidityPool).onAfterLoanTaken(id, creditLine);

        // Emit the event for the loan taken
        emit TakeLoan(id, msg.sender, totalAmount);

        return id;
    }

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 amount) external whenNotPaused onlyOngoingLoan(loanId) {
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        // Get lender
        address lender = ownerOf(loanId);

        // Get stored loan state
        Loan.State storage loan = _loans[loanId];

        // TBD Validate the loan according to the lending market requirements

        if (loan.holder.code.length == 0) {
            // TBD Add support for EOA liquidity pools
            revert Error.NotImplemented();
        }

        // Check for auto repayment
        bool autoRepayment = loan.holder == msg.sender;
        address payer = autoRepayment ? loan.borrower : msg.sender;
        if (autoRepayment && !loan.autoRepayment) {
            revert AutoRepaymentNotAllowed();
        }

        // Calculate the outstanding balance
        (uint256 outstandingBalance, uint256 currentDate) = _outstandingBalance(loan, block.timestamp);

        if (amount == type(uint256).max) {
            amount = outstandingBalance;
        } else if (amount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        // Update the loan state
        outstandingBalance -= amount;
        loan.trackedBorrowAmount = outstandingBalance.toUint64();
        loan.trackedDate = currentDate.toUint32();

        // Notify the liquidity pool before the loan payment
        ILiquidityPool(loan.holder).onBeforeLoanPayment(loanId, amount);

        // Transfer the payment amount from the payer to the liquidity pool
        IERC20(loan.token).transferFrom(payer, loan.holder, amount);

        // Notify the liquidity pool after the loan payment
        ILiquidityPool(loan.holder).onAfterLoanPayment(loanId, amount);

        // Emit the event for the loan payment
        emit RepayLoan(loanId, payer, loan.borrower, amount, outstandingBalance);

        // Transfer the NFT token to the borrower if the loan is repaid
        if (outstandingBalance == 0) {
            _safeTransfer(lender, loan.borrower, loanId, "");
        }
    }

    // -------------------------------------------- //
    //  Loan holder functions                       //
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

        uint256 currentMoratoriumInPeriods = _moratoriumInPeriods(loan);
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
        (preview.outstandingBalance, preview.periodDate) = _outstandingBalance(_loans[loanId], timestamp);
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

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @notice Calculates the outstanding balance of a loan and the current date
    function _outstandingBalance(Loan.State memory loan, uint256 timestamp) internal view returns (uint256, uint256) {
        uint256 outstandingBalance = loan.trackedBorrowAmount;

        uint256 currentDate = calculatePeriodDate(timestamp, loan.periodInSeconds, 0, 0);
        if (loan.freezeDate != 0) {
            currentDate = loan.freezeDate;
        }

        if (currentDate > loan.trackedDate) {
            uint256 dueDate = loan.startDate + loan.durationInPeriods * loan.periodInSeconds;

            if (currentDate < dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - loan.trackedDate) / loan.periodInSeconds,
                    loan.interestRatePrimary,
                    loan.interestRateFactor,
                    loan.interestFormula
                );
            } else if (loan.trackedDate >= dueDate) {
                outstandingBalance = calculateOutstandingBalance(
                    outstandingBalance,
                    (currentDate - loan.trackedDate) / loan.periodInSeconds,
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
            }
        }

        return (outstandingBalance, currentDate);
    }

    /// @notice Calculates the number of moratorium periods of a loan
    function _moratoriumInPeriods(Loan.State storage loan) internal view returns (uint256) {
        uint256 currentDate = calculatePeriodDate(block.timestamp, loan.periodInSeconds, 0, 0);
        return loan.trackedDate > currentDate ? (loan.trackedDate - currentDate) / loan.periodInSeconds : 0;
    }

    /// @notice Creates a new NFT token and mints it to the lender
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
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused returns (address) {
        return super._update(to, tokenId, auth);
    }

    /// @inheritdoc ERC721Upgradeable
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused {
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

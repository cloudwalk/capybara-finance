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

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Interest } from "src/common/libraries/Interest.sol";
import { Constants } from "src/common/libraries/Constants.sol";
import { InterestMath } from "src/common/libraries/InterestMath.sol";
import { SafeCast } from "src/common/libraries/SafeCast.sol";

import { ILendingMarket } from "src/common/interfaces/core/ILendingMarket.sol";
import { ILiquidityPool } from "src/common/interfaces/core/ILiquidityPool.sol";
import { ICreditLine } from "src/common/interfaces/core/ICreditLine.sol";

import { LendingMarketStorage } from "./LendingMarketStorage.sol";

/// @title LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the lending market contract.
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

    /// @dev Thrown when the loan does not exist.
    error LoanNotExist();

    /// @dev Thrown when the loan is not frozen.
    error LoanNotFrozen();

    /// @dev Thrown when the loan is already repaid.
    error LoanAlreadyRepaid();

    /// @dev Thrown when the loan is already frozen.
    error LoanAlreadyFrozen();

    /// @dev Thrown when the credit line is not registered.
    error CreditLineNotRegistered();

    /// @dev Thrown when the liquidity pool is not registered.
    error LiquidityPoolNotRegistered();

    /// @dev Thrown when the credit line is already registered.
    error CreditLineAlreadyRegistered();

    /// @dev Thrown when the liquidity pool is already registered.
    error LiquidityPoolAlreadyRegistered();

    /// @dev Thrown when provided interest rate is inappropriate.
    error InappropriateInterestRate();

    /// @dev Thrown when provided loan duration is inappropriate.
    error InappropriateLoanDuration();

    /// @dev Thrown when loan auto repayment is not allowed.
    error AutoRepaymentNotAllowed();

    /// @dev Thrown when the cooldown period has passed.
    error CooldownPeriodHasPassed();

    /// @dev Thrown when loan revocation is prohibited.
    error RevocationIsProhibited();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @dev Throws if called by any account other than the market registry or the owner.
    modifier onlyRegistryOrOwner() {
        if (msg.sender != _registry && msg.sender != owner()) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @dev Throws if called by any account other than the lender or its alias.
    /// @param loanId The unique identifier of the loan to check.
    modifier onlyLenderOrAlias(uint256 loanId) {
        address lender = ownerOf(loanId);
        if (msg.sender != lender && _hasAlias[lender][msg.sender] == false) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @dev Throws if the loan does not exist or has already been repaid.
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

    /// @dev Initializer of the upgradable contract.
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

    /// @dev Pauses the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Sets the address of the lending market registry.
    /// @param newRegistry The address of the new registry.
    function setRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == _registry) {
            revert Error.AlreadyConfigured();
        }

        emit MarketRegistryChanged(newRegistry, _registry);

        _registry = newRegistry;
    }

    /// @inheritdoc ILendingMarket
    function updateCreditLineLender(address creditLine, address newLender) external onlyOwner {
        if (creditLine == address(0) || newLender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_creditLineLenders[creditLine] == newLender) {
            revert Error.AlreadyConfigured();
        }

        emit CreditLineLenderUpdated(creditLine, newLender, _creditLineLenders[creditLine]);

        _creditLineLenders[creditLine] = newLender;
    }

    /// @inheritdoc ILendingMarket
    function updateLiquidityPoolLender(address liquidityPool, address newLender) external onlyOwner {
        if (liquidityPool == address(0) || newLender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPoolLenders[liquidityPool] == newLender) {
            revert Error.AlreadyConfigured();
        }

        emit LiquidityPoolLenderUpdated(liquidityPool, newLender, _liquidityPoolLenders[liquidityPool]);

        _liquidityPoolLenders[liquidityPool] = newLender;
    }

    // -------------------------------------------- //
    //  Registry & owner functions                  //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function registerCreditLine(address lender, address creditLine) external whenNotPaused onlyRegistryOrOwner {
        if (lender == address(0) || creditLine == address(0)) {
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
        if (lender == address(0) || liquidityPool == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPoolLenders[liquidityPool] != address(0)) {
            revert LiquidityPoolAlreadyRegistered();
        }

        emit LiquidityPoolRegistered(lender, liquidityPool);

        _liquidityPoolLenders[liquidityPool] = lender;
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
        Loan.Terms memory terms = ICreditLine(creditLine).onBeforeLoanTaken(
            msg.sender,
            borrowAmount,
            durationInPeriods,
            id
        );
        uint64 totalBorrowAmount = (borrowAmount + terms.addonAmount).toUint64();
        uint32 blockTimestamp = _blockTimestamp().toUint32();

        _loans[id] = Loan.State({
            token: terms.token,
            borrower: msg.sender,
            treasury: terms.treasury,
            startTimestamp: blockTimestamp,
            durationInPeriods: terms.durationInPeriods,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            interestFormula: terms.interestFormula,
            initialBorrowAmount: totalBorrowAmount,
            trackedBorrowBalance: totalBorrowAmount,
            trackedTimestamp: blockTimestamp,
            freezeTimestamp: 0,
            autoRepayment: terms.autoRepayment,
            cooldownPeriods: terms.cooldownPeriods,
            addonAmount: terms.addonAmount
        });

        ILiquidityPool(liquidityPool).onBeforeLoanTaken(id, creditLine);
        IERC20(terms.token).safeTransferFrom(liquidityPool, msg.sender, borrowAmount);
        ILiquidityPool(liquidityPool).onAfterLoanTaken(id, creditLine);

        emit LoanTaken(id, msg.sender, totalBorrowAmount, terms.durationInPeriods);

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

        (uint256 outstandingBalance,) = _outstandingBalance(loan, _blockTimestamp());

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

        emit LoanRepayment(loanId, payer, loan.borrower, repayAmount, outstandingBalance);

        if (outstandingBalance == 0) {
            _safeTransfer(ownerOf(loanId), loan.borrower, loanId, "");
        }
    }

    /// @inheritdoc ILendingMarket
    function revokeLoan(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.startTimestamp != loan.trackedTimestamp) {
            revert RevocationIsProhibited();
        }

        uint256 currentPeriodIndex = _periodIndex(_blockTimestamp(), Constants.PERIOD_IN_SECONDS);
        uint256 startPeriodIndex = _periodIndex(loan.startTimestamp, Constants.PERIOD_IN_SECONDS);
        if (loan.cooldownPeriods <= currentPeriodIndex - startPeriodIndex) {
            revert CooldownPeriodHasPassed();
        }

        loan.trackedBorrowBalance = 0;

        ILiquidityPool(loan.treasury).onBeforeLoanRevocation(loanId);
        IERC20(loan.token).transferFrom(loan.borrower, loan.treasury, loan.initialBorrowAmount - loan.addonAmount);
        ILiquidityPool(loan.treasury).onAfterLoanRevocation(loanId);

        emit LoanRevoked(loanId);
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

        emit LoanFrozen(loanId);
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) onlyLenderOrAlias(loanId) {
        Loan.State storage loan = _loans[loanId];

        if (loan.freezeTimestamp == 0) {
            revert LoanNotFrozen();
        }

        uint256 currentPeriodIndex = _periodIndex(_blockTimestamp(), Constants.PERIOD_IN_SECONDS);
        uint256 freezePeriodIndex = _periodIndex(loan.freezeTimestamp, Constants.PERIOD_IN_SECONDS);
        uint256 frozenPeriods = currentPeriodIndex - freezePeriodIndex;

        if (frozenPeriods > 0) {
            loan.trackedTimestamp += (frozenPeriods * Constants.PERIOD_IN_SECONDS).toUint32();
            loan.durationInPeriods += frozenPeriods.toUint32();
        }

        loan.freezeTimestamp = 0;

        emit LoanUnfrozen(loanId);
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

    /// @inheritdoc ILendingMarket
    function assignLiquidityPoolToCreditLine(address creditLine, address liquidityPool) external whenNotPaused {
        if (creditLine == address(0) || liquidityPool == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPoolByCreditLine[creditLine] != address(0)) {
            // TBD Check if updating the liquidity pool associated with the credit line
            // will have any unexpected side effects during the loan lifecycle.
            revert Error.NotImplemented();
        }

        if (_creditLineLenders[creditLine] != msg.sender || _liquidityPoolLenders[liquidityPool] != msg.sender) {
            revert Error.Unauthorized();
        }

        emit LiquidityPoolAssignedToCreditLine(creditLine, liquidityPool, _liquidityPoolByCreditLine[creditLine]);

        _liquidityPoolByCreditLine[creditLine] = liquidityPool;
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

        (preview.outstandingBalance, preview.periodIndex) = _outstandingBalance(loan, timestamp);

        return preview;
    }

    /// @inheritdoc ILendingMarket
    function hasAlias(address lender, address account) external view returns (bool) {
        return _hasAlias[lender][account];
    }

    /// @inheritdoc ILendingMarket
    function interestRateFactor() external view returns (uint256) {
        return Constants.INTEREST_RATE_FACTOR;
    }

    /// @inheritdoc ILendingMarket
    function periodInSeconds() external view returns (uint256) {
        return Constants.PERIOD_IN_SECONDS;
    }

    /// @inheritdoc ILendingMarket
    function timeShift() external view returns (uint256, bool) {
        return (Constants.NEGATIVE_TIME_SHIFT, false);
    }

    /// @inheritdoc ILendingMarket
    function registry() external view returns (address) {
        return _registry;
    }

    /// @dev Calculates the period index that corresponds the specified timestamp.
    /// @param timestamp The timestamp to calculate the period index.
    /// @param periodInSeconds The period duration in seconds.
    function calculatePeriodIndex(uint256 timestamp, uint256 periodInSeconds) external pure returns (uint256) {
        return _periodIndex(timestamp, periodInSeconds);
    }

    /// @dev Calculates the outstanding balance of a loan.
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
        return
            InterestMath.calculateOutstandingBalance(
                originalBalance,
                numberOfPeriods,
                interestRate,
                interestRateFactor,
                interestFormula
            );
    }

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @dev Calculates the outstanding balance of a loan.
    /// @param loan The loan to calculate the outstanding balance for.
    /// @param timestamp The timestamp to calculate the outstanding balance at.
    /// @return outstandingBalance The outstanding balance of the loan at the specified timestamp.
    /// @return periodIndex The period index that corresponds the provided timestamp.
    function _outstandingBalance(
        Loan.State storage loan,
        uint256 timestamp
    ) internal view returns (uint256 outstandingBalance, uint256 periodIndex) {
        outstandingBalance = loan.trackedBorrowBalance;

        if (loan.freezeTimestamp != 0) {
            timestamp = loan.freezeTimestamp;
        }

        periodIndex = _periodIndex(timestamp, Constants.PERIOD_IN_SECONDS);
        uint256 trackedPeriodIndex = _periodIndex(loan.trackedTimestamp, Constants.PERIOD_IN_SECONDS);

        if (periodIndex > trackedPeriodIndex) {
            uint256 startPeriodIndex = _periodIndex(loan.startTimestamp, Constants.PERIOD_IN_SECONDS);
            uint256 duePeriodIndex = startPeriodIndex + loan.durationInPeriods;
            if (periodIndex < duePeriodIndex) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    periodIndex - trackedPeriodIndex,
                    loan.interestRatePrimary,
                    Constants.INTEREST_RATE_FACTOR,
                    loan.interestFormula
                );
            } else if (trackedPeriodIndex >= duePeriodIndex) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    periodIndex - trackedPeriodIndex,
                    loan.interestRateSecondary,
                    Constants.INTEREST_RATE_FACTOR,
                    loan.interestFormula
                );
            } else {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    duePeriodIndex - trackedPeriodIndex,
                    loan.interestRatePrimary,
                    Constants.INTEREST_RATE_FACTOR,
                    loan.interestFormula
                );
                if (periodIndex > duePeriodIndex) {
                    outstandingBalance = InterestMath.calculateOutstandingBalance(
                        outstandingBalance,
                        periodIndex - duePeriodIndex,
                        loan.interestRateSecondary,
                        Constants.INTEREST_RATE_FACTOR,
                        loan.interestFormula
                    );
                }
            }
        }
    }

    /// @dev Mints a new NFT token.
    /// @param to The address to mint the token to.
    /// @return The unique identifier of the minted token.
    function _safeMint(address to) internal returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    /// @dev Calculates the period index that corresponds the specified timestamp.
    function _periodIndex(uint256 timestamp, uint256 periodInSeconds) internal pure returns (uint256) {
        return (timestamp / periodInSeconds);
    }

    /// @dev Returns the current block timestamp.
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp - Constants.NEGATIVE_TIME_SHIFT;
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

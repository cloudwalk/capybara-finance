// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { Round } from "src/common/libraries/Round.sol";
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
    AccessControlUpgradeable,
    PausableUpgradeable,
    ILendingMarket
{
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @dev The role of this contract owner.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

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

    /// @dev Thrown when the credit line is not configured.
    error CreditLineLenderNotConfigured();

    /// @dev Thrown when the liquidity pool is not configured.
    error LiquidityPoolLenderNotConfigured();

    /// @dev Thrown when provided interest rate is inappropriate.
    error InappropriateInterestRate();

    /// @dev Thrown when provided loan duration is inappropriate.
    error InappropriateLoanDuration();

    /// @dev Thrown when loan auto repayment is not allowed.
    error AutoRepaymentNotAllowed();

    /// @dev Thrown when the cooldown period has passed.
    error CooldownPeriodHasPassed();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @dev Throws if called by any account other than the lender or its alias.
    /// @param loanId The unique identifier of the loan to check.
    modifier onlyLenderOrAlias(uint256 loanId) {
        if (!isLenderOrAlias(loanId, msg.sender)) {
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
        if (_loans[loanId].trackedBalance == 0) {
            revert LoanAlreadyRepaid();
        }
        _;
    }

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @dev Initializer of the upgradable contract.
    /// @param owner_ The owner of the contract.
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function initialize(address owner_) external initializer {
        __LendingMarket_init(owner_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param owner_ The owner of the contract.
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function __LendingMarket_init(address owner_) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        __LendingMarket_init_unchained(owner_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param owner_ The owner of the contract.
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function __LendingMarket_init_unchained(address owner_) internal onlyInitializing {
        _grantRole(OWNER_ROLE, owner_);
    }

    // -------------------------------------------- //
    //  Owner functions                             //
    // -------------------------------------------- //

    /// @dev Pauses the contract.
    function pause() external onlyRole(OWNER_ROLE) {
        _pause();
    }

    /// @dev Unpauses the contract.
    function unpause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    /// @inheritdoc ILendingMarket
    function configureCreditLineLender(address creditLine, address newLender) external onlyRole(OWNER_ROLE) {
        if (creditLine == address(0) || newLender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_creditLineLenders[creditLine] == newLender) {
            revert Error.AlreadyConfigured();
        }

        emit CreditLineLenderConfigured(creditLine, newLender, _creditLineLenders[creditLine]);

        _creditLineLenders[creditLine] = newLender;
    }

    /// @inheritdoc ILendingMarket
    function configureLiquidityPoolLender(address liquidityPool, address newLender) external onlyRole(OWNER_ROLE) {
        if (liquidityPool == address(0) || newLender == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_liquidityPoolLenders[liquidityPool] == newLender) {
            revert Error.AlreadyConfigured();
        }

        emit LiquidityPoolLenderConfigured(liquidityPool, newLender, _liquidityPoolLenders[liquidityPool]);

        _liquidityPoolLenders[liquidityPool] = newLender;
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
        if (borrowAmount != Round.roundUp(borrowAmount, Constants.ACCURACY_FACTOR)) {
            revert Error.InvalidAmount();
        }

        address lender = _creditLineLenders[creditLine];
        if (lender == address(0)) {
            revert CreditLineLenderNotConfigured();
        }

        address liquidityPool = _creditLineToLiquidityPool[creditLine];
        if (liquidityPool == address(0)) {
            revert LiquidityPoolLenderNotConfigured();
        }

        if (lender != _liquidityPoolLenders[liquidityPool]) {
            revert Error.Unauthorized();
        }

        uint256 id = _loanIdCounter++;
        _lenders[id].account = lender;

        Loan.Terms memory terms = ICreditLine(creditLine).onBeforeLoanTaken(
            id,
            msg.sender,
            borrowAmount,
            durationInPeriods
        );

        uint32 blockTimestamp = _blockTimestamp().toUint32();
        uint256 totalBorrowAmount = borrowAmount + terms.addonAmount;

        _loans[id] = Loan.State({
            token: terms.token,
            borrower: msg.sender,
            treasury: terms.treasury,
            startTimestamp: blockTimestamp,
            durationInPeriods: terms.durationInPeriods,
            interestRatePrimary: terms.interestRatePrimary,
            interestRateSecondary: terms.interestRateSecondary,
            borrowAmount: borrowAmount.toUint64(),
            trackedBalance: totalBorrowAmount.toUint64(),
            repaidAmount: 0,
            trackedTimestamp: blockTimestamp,
            freezeTimestamp: 0,
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
        (uint256 outstandingBalance, ) = _outstandingBalance(loan, _blockTimestamp());

        // Full repayment
        if (repayAmount == type(uint256).max) {
            outstandingBalance = Round.roundUp(outstandingBalance, Constants.ACCURACY_FACTOR);
            _repayLoan(loanId, loan, outstandingBalance, outstandingBalance);
            return;
        }

        if (repayAmount != Round.roundUp(repayAmount, Constants.ACCURACY_FACTOR)) {
            revert Error.InvalidAmount();
        }

        // Full repayment
        if (repayAmount == Round.roundUp(outstandingBalance, Constants.ACCURACY_FACTOR)) {
            _repayLoan(loanId, loan, repayAmount, repayAmount);
            return;
        }

        if (repayAmount > outstandingBalance) {
            revert Error.InvalidAmount();
        }

        // Partial repayment
        _repayLoan(loanId, loan, repayAmount, outstandingBalance);
    }

    /// @dev Updates the loan state and makes the necessary transfers when repaying a loan.
    /// @param loanId The unique identifier of the loan to repay.
    /// @param loan The storage state of the loan to update.
    /// @param repayAmount The amount to repay.
    /// @param outstandingBalance The outstanding balance of the loan.
    function _repayLoan(
        uint256 loanId,
        Loan.State storage loan,
        uint256 repayAmount,
        uint256 outstandingBalance
    ) internal {
        if (loan.treasury.code.length == 0) {
            // TBD Add support for EOA liquidity pools.
            revert Error.NotImplemented();
        }

        bool autoRepayment = loan.treasury == msg.sender;
        address payer = autoRepayment ? loan.borrower : msg.sender;
        if (autoRepayment && !Constants.AUTO_REPAYMENT_ENABLED) {
            revert AutoRepaymentNotAllowed();
        }

        outstandingBalance -= repayAmount;

        ILiquidityPool(loan.treasury).onBeforeLoanPayment(loanId, repayAmount);

        loan.repaidAmount += repayAmount.toUint64();
        loan.trackedBalance = outstandingBalance.toUint64();
        loan.trackedTimestamp = _blockTimestamp().toUint32();

        IERC20(loan.token).transferFrom(payer, loan.treasury, repayAmount);

        ILiquidityPool(loan.treasury).onAfterLoanPayment(loanId, repayAmount);

        emit LoanRepayment(loanId, payer, loan.borrower, repayAmount, outstandingBalance);
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

        address oldLiquidityPool = _creditLineToLiquidityPool[creditLine];
        if (oldLiquidityPool != address(0)) {
            // TBD Check if updating the liquidity pool associated with the credit line
            // will have any unexpected side effects during the loan lifecycle.
            revert Error.NotImplemented();
        }

        if (_creditLineLenders[creditLine] != msg.sender || _liquidityPoolLenders[liquidityPool] != msg.sender) {
            revert Error.Unauthorized();
        }

        emit LiquidityPoolAssignedToCreditLine(creditLine, liquidityPool, oldLiquidityPool);

        _creditLineToLiquidityPool[creditLine] = liquidityPool;
    }

    // -------------------------------------------- //
    //  Borrower and lender functions               //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function revokeLoan(uint256 loanId) external whenNotPaused onlyOngoingLoan(loanId) {
        Loan.State storage loan = _loans[loanId];
        address sender = msg.sender;

        if (sender == loan.borrower) {
            uint256 currentPeriodIndex = _periodIndex(_blockTimestamp(), Constants.PERIOD_IN_SECONDS);
            uint256 startPeriodIndex = _periodIndex(loan.startTimestamp, Constants.PERIOD_IN_SECONDS);
            if (currentPeriodIndex - startPeriodIndex >= Constants.COOLDOWN_IN_PERIODS) {
                revert CooldownPeriodHasPassed();
            }
            _revokeLoan(loanId, loan);
        } else if (isLenderOrAlias(loanId, msg.sender)) {
            _revokeLoan(loanId, loan);
        } else {
            revert Error.Unauthorized();
        }
    }

    /// @dev Updates the loan state and makes the necessary transfers when revoking a loan.
    /// @param loanId The unique identifier of the loan to revoke.
    /// @param loan The storage state of the loan to update.
    function _revokeLoan(uint256 loanId, Loan.State storage loan) internal {
        ILiquidityPool(loan.treasury).onBeforeLoanRevocation(loanId);

        loan.trackedBalance = 0;
        loan.trackedTimestamp = _blockTimestamp().toUint32();

        if (loan.repaidAmount < loan.borrowAmount) {
            IERC20(loan.token).transferFrom(loan.borrower, loan.treasury, loan.borrowAmount - loan.repaidAmount);
        } else if (loan.repaidAmount != loan.borrowAmount) {
            IERC20(loan.token).transferFrom(loan.treasury, loan.borrower, loan.repaidAmount - loan.borrowAmount);
        }

        emit LoanRevoked(loanId);

        ILiquidityPool(loan.treasury).onAfterLoanRevocation(loanId);
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
        return _creditLineToLiquidityPool[creditLine];
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

        (preview.trackedBalance, preview.periodIndex) = _outstandingBalance(loan, timestamp);
        preview.outstandingBalance = Round.roundUp(preview.trackedBalance, Constants.ACCURACY_FACTOR);

        return preview;
    }

    /// @inheritdoc ILendingMarket
    function isLenderOrAlias(uint256 loanId, address account) public view returns (bool) {
        address lender = _lenders[loanId].account;
        return account == lender || _hasAlias[lender][account];
    }

    /// @inheritdoc ILendingMarket
    function getLoanLender(uint256 loanId) external view returns (Loan.Lender memory) {
        return _lenders[loanId];
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
    function timeOffset() external view returns (uint256, bool) {
        return (Constants.NEGATIVE_TIME_OFFSET, false);
    }

    /// @inheritdoc ILendingMarket
    function loanCounter() external view returns (uint256) {
        return _loanIdCounter;
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
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor
    ) external pure returns (uint256) {
        return
            InterestMath.calculateOutstandingBalance(
                originalBalance,
                numberOfPeriods,
                interestRate,
                interestRateFactor
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
        outstandingBalance = loan.trackedBalance;

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
                    Constants.INTEREST_RATE_FACTOR
                );
            } else if (trackedPeriodIndex >= duePeriodIndex) {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    periodIndex - trackedPeriodIndex,
                    loan.interestRateSecondary,
                    Constants.INTEREST_RATE_FACTOR
                );
            } else {
                outstandingBalance = InterestMath.calculateOutstandingBalance(
                    outstandingBalance,
                    duePeriodIndex - trackedPeriodIndex,
                    loan.interestRatePrimary,
                    Constants.INTEREST_RATE_FACTOR
                );
                if (periodIndex > duePeriodIndex) {
                    outstandingBalance = InterestMath.calculateOutstandingBalance(
                        outstandingBalance,
                        periodIndex - duePeriodIndex,
                        loan.interestRateSecondary,
                        Constants.INTEREST_RATE_FACTOR
                    );
                }
            }
        }
    }

    /// @dev Calculates the period index that corresponds the specified timestamp.
    function _periodIndex(uint256 timestamp, uint256 periodInSeconds) internal pure returns (uint256) {
        return (timestamp / periodInSeconds);
    }

    /// @dev Returns the current block timestamp.
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp - Constants.NEGATIVE_TIME_OFFSET;
    }
}

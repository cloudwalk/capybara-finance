// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { AccessControlExtUpgradeable } from "src/common/AccessControlExtUpgradeable.sol";
import { Borrower } from "src/common/libraries/Borrower.sol";
import { Constants } from "src/common/libraries/Constants.sol";
import { LendingMath } from "src/common/libraries/LendingMath.sol";
import { Loan } from "src/common/libraries/Loan.sol";
import { Error } from "src/common/libraries/Error.sol";
import { SafeCast } from "src/common/libraries/SafeCast.sol";

import { ILendingMarket } from "src/common/interfaces/core/ILendingMarket.sol";

import { LendingMarketStorage } from "./LendingMarketStorage.sol";

/// @title LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the lending market contract.
contract LendingMarket is
    LendingMarketStorage,
    Initializable,
    AccessControlExtUpgradeable,
    PausableUpgradeable,
    ILendingMarket
{
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @dev The role of this contract owner.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev TODO
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev TODO
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

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
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(MANAGER_ROLE, OWNER_ROLE);
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

    // -------------------------------------------- //
    //  Admin functions                             //
    // -------------------------------------------- //

    /// @dev TODO
    function createBorrowerConfig(
        bytes32 configId,
        Borrower.Config calldata newConfig
    ) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (configId == bytes32(0)) {
            revert Error.ConfigIdInvalid();
        }
        if (_borrowerConfigs[configId].expiration != 0) {
            revert Error.AlreadyConfigured();
        }
        _checkBorrowerConfig(newConfig);
        _borrowerConfigs[configId] = newConfig;
        emit BorrowerConfigCreated(configId);
    }

    /// @dev TODO
    function assignConfigToBorrowers(
        bytes32 newConfigId,
        address[] calldata borrowers
    ) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (newConfigId == bytes32(0)) {
            revert Error.ConfigIdInvalid();
        }
        uint256 len = borrowers.length;
        for (uint256 i = 0; i < len; ++i) {
            address borrower = borrowers[i];
            _assignConfigToBorrower(borrower, newConfigId);
        }
    }

    /// @dev TODO
    function deposit(uint256 amount) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        _poolBalance += amount.toUint64();
        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(amount);
    }

    /// @dev TODO
    function withdraw(uint256 poolAmount, uint256 addonAmount) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (poolAmount == 0 && addonAmount == 0) {
            revert Error.InvalidAmount();
        }
        if (_poolBalance < poolAmount) {
            revert Error.PoolBalanceInsufficient();
        }
        if (_addonBalance < addonAmount) {
            revert Error.AddonBalanceInsufficient();
        }

        unchecked {
            _poolBalance -= poolAmount.toUint64();
            _addonBalance -= addonAmount.toUint64();
        }

        IERC20(_token).safeTransfer(msg.sender, poolAmount + addonAmount);

        emit Withdrawal(poolAmount, addonAmount);
    }

    /// @dev TODO
    function rescue(address token_, uint256 amount) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (token_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20(token_).safeTransfer(msg.sender, amount);

        emit Rescue(token_, amount);
    }

    /// @dev TODO
    function changeBorrowerAllowance(
        address borrower,
        int256 changeAmount
    ) whenNotPaused onlyRole(ADMIN_ROLE) external {
        if (borrower == address(0)) {
            revert Error.ZeroAddress();
        }
        Borrower.State storage state = _borrowerStates[borrower];
        int256 oldAllowance = int256(uint256(state.allowance));
        int256 newAllowance;
        if (changeAmount == type(int256).min) {
            newAllowance = 0;
        } else {
            newAllowance = oldAllowance + changeAmount;
            if (newAllowance < 0) {
                revert Error.InvalidAmount();
            }
        }
        if (newAllowance == oldAllowance) {
            revert Error.AlreadyConfigured();
        }
        state.allowance = uint256(newAllowance).toUint64();
        emit BorrowerAllowanceUpdated(borrower, uint256(newAllowance), uint256(oldAllowance));
    }

    // -------------------------------------------- //
    //  Manager functions                           //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function takeLoanFor(
        address borrower,
        uint256 loanAmount,
        uint256 addonAmount,
        uint256 durationInPeriods,
        uint256 interestRatePrimary,
        uint256 interestRateSecondary
    ) external whenNotPaused onlyRole(MANAGER_ROLE) returns (uint256) {
        Loan.Terms memory terms = Loan.Terms({
            borrower: borrower,
            loanAmount: loanAmount,
            addonAmount: addonAmount,
            durationInPeriods: durationInPeriods,
            interestRatePrimary: interestRatePrimary,
            interestRateSecondary: interestRateSecondary
        });
        return _takeLoan(terms);
    }

    /// @inheritdoc ILendingMarket
    function autoRepayLoans(
        uint256[] calldata loanIds,
        uint256[] calldata amounts
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        uint256 len = loanIds.length;
        if (len != amounts.length) {
            revert Error.ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < len; ++i) {
            uint256 loanId = loanIds[i];
            uint256 amount = amounts[i];
            if (_isLoanOngoing(_loans[loanId])) {
                _repayLoan(
                    loanId,
                    amount,
                    address(this) // source
                );
            } else {
                revert Error.LoanStateInappropriate(loanId);
            }
        }
    }

    /// @inheritdoc ILendingMarket
    function revokeLoan(uint256 loanId) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        loan.trackedBalance = 0;
        loan.trackedTimestamp = _blockTimestamp().toUint32();
        _processLoanFinishing(loan);

        if (loan.repaidAmount < loan.loanAmount) {
            IERC20(_token).safeTransferFrom(loan.borrower, address(this), loan.loanAmount - loan.repaidAmount);
            _poolBalance = _poolBalance + (loan.loanAmount - loan.repaidAmount) + loan.addonAmount;
        } else if (loan.repaidAmount != loan.loanAmount) {
            _poolBalance = _poolBalance - (loan.repaidAmount - loan.loanAmount) + loan.addonAmount;
            IERC20(_token).safeTransfer(loan.borrower, loan.repaidAmount - loan.loanAmount);
        }
        _addonBalance -= loan.addonAmount;

        emit LoanRevoked(loanId, msg.sender);
    }

    /// @inheritdoc ILendingMarket
    function freeze(uint256 loanId) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        if (loan.freezeTimestamp != 0) {
            revert Error.LoanAlreadyFrozen();
        }

        loan.freezeTimestamp = _blockTimestamp().toUint32();

        emit LoanFrozen(loanId);
    }

    /// @inheritdoc ILendingMarket
    function unfreeze(uint256 loanId) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        if (loan.freezeTimestamp == 0) {
            revert Error.LoanNotFrozen();
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
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        if (newDurationInPeriods <= loan.durationInPeriods) {
            revert Error.LoanDurationInappropriate();
        }

        emit LoanDurationUpdated(loanId, newDurationInPeriods, loan.durationInPeriods);

        loan.durationInPeriods = newDurationInPeriods.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRatePrimary(
        uint256 loanId,
        uint256 newInterestRate
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        if (newInterestRate >= loan.interestRatePrimary) {
            revert Error.InterestRateInappropriate();
        }

        emit LoanInterestRatePrimaryUpdated(loanId, newInterestRate, loan.interestRatePrimary);

        loan.interestRatePrimary = newInterestRate.toUint32();
    }

    /// @inheritdoc ILendingMarket
    function updateLoanInterestRateSecondary(
        uint256 loanId,
        uint256 newInterestRate
    ) external whenNotPaused onlyRole(MANAGER_ROLE) {
        Loan.State storage loan = _loans[loanId];
        _checkLoanOngoing(loan);

        if (newInterestRate >= loan.interestRateSecondary) {
            revert Error.InterestRateInappropriate();
        }

        emit LoanInterestRateSecondaryUpdated(loanId, newInterestRate, loan.interestRateSecondary);

        loan.interestRateSecondary = newInterestRate.toUint32();
    }

    // -------------------------------------------- //
    //  Borrower functions                          //
    // -------------------------------------------- //

    /// @inheritdoc ILendingMarket
    function repayLoan(uint256 loanId, uint256 amount) external {
        _repayLoan(
            loanId,
            amount,
            msg.sender // source
        );
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

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
        preview.outstandingBalance = LendingMath.roundUp(preview.trackedBalance, Constants.ACCURACY_FACTOR);

        return preview;
    }

    /// @dev TODO
    function getBorrowerConfigByAddress(address borrower) external view returns (Borrower.Config memory) {
        return _getBorrowerConfig(borrower);
    }

    /// @dev TODO
    function getBorrowerConfigById(bytes32 id) external view returns (Borrower.Config memory) {
        return _borrowerConfigs[id];
    }

    /// @dev TODO
    function getBorrowerConfigId(address borrower) external view returns (bytes32) {
        return _borrowerConfigIds[borrower];
    }

    /// @dev TODO
    function getBorrowerState(address borrower) external view returns (Borrower.State memory) {
        return _borrowerStates[borrower];
    }

    /// @inheritdoc ILendingMarket
    function interestRateFactor() external pure returns (uint256) {
        return Constants.INTEREST_RATE_FACTOR;
    }

    /// @inheritdoc ILendingMarket
    function periodInSeconds() external pure returns (uint256) {
        return Constants.PERIOD_IN_SECONDS;
    }

    /// @inheritdoc ILendingMarket
    function timeOffset() external pure returns (int256) {
        return Constants.TIME_OFFSET;
    }

    /// @inheritdoc ILendingMarket
    function loanCounter() external view returns (uint256) {
        return _loanCounter;
    }

    /// @dev TODO
    function token() external view returns (address) {
        return _token;
    }

    /// @dev TODO
    function poolBalance() external view returns (uint256) {
        return _poolBalance;
    }

    /// @dev TODO
    function addonBalance() external view returns (uint256) {
        return _addonBalance;
    }

    /// @dev Calculates the period index that corresponds the specified timestamp.
    /// @param timestamp The timestamp to calculate the period index.
    /// @param periodInSeconds_ The period duration in seconds.
    function calculatePeriodIndex(uint256 timestamp, uint256 periodInSeconds_) external pure returns (uint256) {
        return _periodIndex(timestamp, periodInSeconds_);
    }

    /// @dev Calculates the outstanding balance of a loan.
    /// @param originalBalance The balance of the loan at the beginning.
    /// @param numberOfPeriods The number of periods to calculate the outstanding balance.
    /// @param interestRate The interest rate applied to the loan.
    /// @param interestRateFactor_ The interest rate factor.
    function calculateOutstandingBalance(
        uint256 originalBalance,
        uint256 numberOfPeriods,
        uint256 interestRate,
        uint256 interestRateFactor_
    ) external pure returns (uint256) {
        return LendingMath.calculateOutstandingBalance(
            originalBalance,
            numberOfPeriods,
            interestRate,
            interestRateFactor_
        );
    }

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    function _isLoanOngoing(Loan.State storage loan) internal view returns (bool) {
        return loan.borrower != address(0) && loan.trackedBalance != 0;
    }

    function _checkLoanOngoing(Loan.State storage loan) internal view {
        if (_isLoanOngoing(loan)) {
            return;
        }
        if (loan.borrower == address(0)) {
            revert Error.LoanNonExistent();
        } else {
            revert Error.LoanAlreadyRepaid();
        }
    }

    /// @dev TODO
    function _takeLoan(Loan.Terms memory terms) internal returns (uint256 loanId) {
        Borrower.State storage borrowerState = _borrowerStates[terms.borrower];
        Borrower.Config storage borrowerConfig = _getBorrowerConfig(terms.borrower);
        uint256 oldBorrowerAllowance = _getBorrowAllowance(borrowerState, borrowerConfig);
        _checkLoanPossibility(terms, oldBorrowerAllowance, borrowerConfig, borrowerState);

        loanId = _loanCounter++;
        uint32 blockTimestamp = _blockTimestamp().toUint32();
        uint64 totalLoanAmount = (terms.loanAmount + terms.addonAmount).toUint64();
        uint64 addonAmount = terms.addonAmount.toUint64();

        _loans[loanId] = Loan.State({
            borrower: terms.borrower,
            loanAmount: totalLoanAmount,
            startTimestamp: blockTimestamp,
            repaidAmount: 0,
            trackedBalance: totalLoanAmount,
            trackedTimestamp: blockTimestamp,
            freezeTimestamp: 0,
            durationInPeriods: terms.durationInPeriods.toUint32(),
            addonAmount: addonAmount,
            interestRatePrimary: terms.interestRatePrimary.toUint32(),
            interestRateSecondary: terms.interestRateSecondary.toUint32()
        });

        _poolBalance -= totalLoanAmount;
        _addonBalance += addonAmount;

        ++borrowerState.totalLoanCounter;
        ++borrowerState.activeLoanCounter;
        borrowerState.allowance = _defineNewBorrowerAllowance(
            oldBorrowerAllowance,
            totalLoanAmount,
            borrowerConfig
        ).toUint64();

        IERC20(_token).safeTransfer(terms.borrower, terms.loanAmount);

        emit LoanTaken(
            loanId,
            terms.borrower,
            terms.loanAmount,
            terms.durationInPeriods,
            terms.addonAmount,
            terms.interestRatePrimary,
            terms.interestRateSecondary,
            msg.sender
        );

        return loanId;
    }

    /// @dev TODO
    function _defineNewBorrowerAllowance(
        uint256 oldBorrowerAllowance,
        uint256 totalLoanAmount,
        Borrower.Config storage borrowerConfig
    ) internal returns (uint256) {
        if (borrowerConfig.allowancePolicy == Borrower.AllowancePolicy.Keep) {
            return oldBorrowerAllowance;
        } else if (
            borrowerConfig.allowancePolicy == Borrower.AllowancePolicy.Decrease ||
            borrowerConfig.allowancePolicy == Borrower.AllowancePolicy.Iterate
        ) {
            return oldBorrowerAllowance - totalLoanAmount;
        }

        return 0;
    }

    /// @dev
    function _getBorrowerConfig(address borrower) internal view returns (Borrower.Config storage) {
        bytes32 configId = _borrowerConfigIds[borrower];
        Borrower.Config storage config = _borrowerConfigs[configId];
        if (config.expiration == 0) {
            revert Error.BorrowerNonConfigured();
        }
        return config;
    }

    /// @dev TODO
    function _checkBorrowerConfig(Borrower.Config calldata config) internal pure {
        if (config.expiration == 0 || config.maxLoanAmount == 0 || config.maxActiveLoanCounter == 0) {
            revert Error.BorrowerConfigInvalid();
        }
    }

    /// @dev TODO
    function _assignConfigToBorrower(address borrower, bytes32 newConfigId) internal {
        bytes32 oldConfigId = _borrowerConfigIds[borrower];
        if (oldConfigId != newConfigId) {
            _borrowerConfigIds[borrower] = newConfigId;
            emit BorrowerConfigAssigned(borrower, newConfigId, oldConfigId);
        }
    }

    /// @dev TODO
    function _checkLoanPossibility(
        Loan.Terms memory terms,
        uint256 borrowerAllowance,
        Borrower.Config storage borrowerConfig,
        Borrower.State storage borrowerState
    ) internal view {
        uint256 loanAmount = terms.loanAmount;
        if (loanAmount == 0) {
            revert Error.InvalidAmount();
        }
        if (loanAmount != LendingMath.roundUp(loanAmount, Constants.ACCURACY_FACTOR)) {
            revert Error.InvalidAmount();
        }
        if (loanAmount > borrowerConfig.maxLoanAmount) {
            revert Error.InvalidAmount();
        }
        if (loanAmount < borrowerConfig.minLoanAmount) {
            revert Error.InvalidAmount();
        }
        if (_blockTimestamp() >= borrowerConfig.expiration) {
            revert Error.BorrowerConfigExpired();
        }
        if (borrowerAllowance < loanAmount) {
            revert Error.BorrowerAllowanceInsufficient();
        }
        if (borrowerState.activeLoanCounter + 1 > borrowerConfig.maxActiveLoanCounter) {
            revert Error.ActiveLoanCounterExceeded();
        }
        if (_poolBalance < loanAmount + terms.addonAmount) {
            revert Error.PoolBalanceInsufficient();
        }
    }

    function _getBorrowAllowance(
        Borrower.State storage borrowerState,
        Borrower.Config storage borrowerConfig
    ) internal view returns (uint256) {
        if (borrowerState.totalLoanCounter == 0) {
            return borrowerConfig.maxLoanAmount;
        } else {
            return borrowerState.allowance;
        }
    }

    function _repayLoan(uint256 loanId, uint256 amount, address source) internal {
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        Loan.State storage loan = _loans[loanId];

        (uint256 outstandingBalance,) = _outstandingBalance(loan, _blockTimestamp());

        if (amount == type(uint256).max) {
            amount = LendingMath.roundUp(outstandingBalance, Constants.ACCURACY_FACTOR);
            outstandingBalance = 0;
        } else {
            if (amount != LendingMath.roundUp(amount, Constants.ACCURACY_FACTOR)) {
                revert Error.InvalidAmount();
            }
            uint256 roundedOutstandingBalance = LendingMath.roundUp(outstandingBalance, Constants.ACCURACY_FACTOR);
            if (amount < roundedOutstandingBalance) {
                outstandingBalance -= amount;
            } else {
                if (amount > roundedOutstandingBalance) {
                    revert Error.InvalidAmount();
                }
                outstandingBalance = 0;
            }
        }

        loan.repaidAmount += amount.toUint64();
        loan.trackedBalance = outstandingBalance.toUint64();
        loan.trackedTimestamp = _blockTimestamp().toUint32();
        _poolBalance += amount.toUint64();
        if (outstandingBalance == 0) {
            _processLoanFinishing(loan);
        }

        IERC20(_token).safeTransferFrom(source, address(this), amount);

        emit LoanRepayment(loanId, loan.borrower, source, amount, outstandingBalance, msg.sender);
    }

    function _processLoanFinishing(Loan.State storage loan) internal {
        address borrower = loan.borrower;
        Borrower.State storage borrowerSate = _borrowerStates[borrower];
        Borrower.Config storage borrowerConfig = _getBorrowerConfig(borrower);
        uint64 borrowerAllowance = borrowerSate.allowance;
        Borrower.AllowancePolicy policy = borrowerConfig.allowancePolicy;
        if (policy == Borrower.AllowancePolicy.Iterate) {
            borrowerAllowance += loan.loanAmount;
        }

        borrowerSate.activeLoanCounter -= 1;
        borrowerSate.allowance = borrowerAllowance;
    }

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
                outstandingBalance = LendingMath.calculateOutstandingBalance(
                    outstandingBalance,
                    periodIndex - trackedPeriodIndex,
                    loan.interestRatePrimary,
                    Constants.INTEREST_RATE_FACTOR
                );
            } else if (trackedPeriodIndex >= duePeriodIndex) {
                outstandingBalance = LendingMath.calculateOutstandingBalance(
                    outstandingBalance,
                    periodIndex - trackedPeriodIndex,
                    loan.interestRateSecondary,
                    Constants.INTEREST_RATE_FACTOR
                );
            } else {
                outstandingBalance = LendingMath.calculateOutstandingBalance(
                    outstandingBalance,
                    duePeriodIndex - trackedPeriodIndex,
                    loan.interestRatePrimary,
                    Constants.INTEREST_RATE_FACTOR
                );
                if (periodIndex > duePeriodIndex) {
                    outstandingBalance = LendingMath.calculateOutstandingBalance(
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
    function _periodIndex(uint256 timestamp, uint256 periodInSeconds_) internal pure returns (uint256) {
        return (timestamp / periodInSeconds_);
    }

    /// @dev Returns the current block timestamp.
    function _blockTimestamp() internal view virtual returns (uint256) {
        if (Constants.TIME_OFFSET < 0) {
            return block.timestamp - uint256(- Constants.TIME_OFFSET);
        } else {
            return block.timestamp + uint256(Constants.TIME_OFFSET);
        }
    }
}

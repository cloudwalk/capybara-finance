// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "../common/libraries/Loan.sol";
import { Error } from "../common/libraries/Error.sol";
import { SafeCast } from "../common/libraries/SafeCast.sol";

import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";
import { ILendingMarket } from "../common/interfaces/core/ILendingMarket.sol";
import { ILiquidityPool } from "../common/interfaces/core/ILiquidityPool.sol";
import { ILiquidityPoolAccountable } from "../common/interfaces/ILiquidityPoolAccountable.sol";
import { AccessControlExtUpgradeable } from "../common/AccessControlExtUpgradeable.sol";
import { Versionable } from "../common/Versionable.sol";

/// @title LiquidityPoolAccountable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the accountable liquidity pool contract.
contract LiquidityPoolAccountable is
    AccessControlExtUpgradeable,
    PausableUpgradeable,
    ILiquidityPoolAccountable,
    Versionable
{
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for uint64;

    /// @dev The role of this contract owner.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev The role of this contract admin.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev The role of this contract pauser.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @dev The address of the underlying token.
    address internal _token;

    /// @dev The address of the associated market.
    address internal _market;

    /// @dev The borrowable balance of the liquidity pool.
    uint64 internal _borrowableBalance;

    /// @dev The addons balance of the liquidity pool.
    uint64 internal _addonsBalance;

    /// @dev @TODO
    LiquidityPoolConfig _config;

    /// @dev This empty reserved space is put in place to allow future versions
    /// to add new variables without shifting down storage in the inheritance chain.
    uint256[45] private __gap;

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @dev TODO
    /// Switching `Transfer` => `Retention` is prohibited because this can lead to a situation where
    /// a loan is taken in mode `Transfer` and revoked in mode `Retention`, which will lead to
    /// an incorrect value of the `_addonsBalance` variable, or a reversion if `_addonsBalance == 0`.
    error AddonActionKindSwitchProhibited();

    /// @dev TODO
    error AddonTreasuryAddressZero();

    /// @dev TODO
    error AddonTreasuryInsufficientAllowance();

    /// @dev Thrown when the token source balance is insufficient.
    error InsufficientBalance();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @dev Throws if called by any account other than the lending market.
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @dev Initializer of the upgradable contract.
    /// @param lender_ The address of the liquidity pool lender.
    /// @param market_ The address of the lending market.
    /// @param token_ The address of the token.
    /// @param addonTreasury_ TODO
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function initialize(
        address lender_, // Tools: this comment prevents Prettier from formatting into a single line.
        address market_,
        address token_,
        address addonTreasury_
    ) external initializer {
        __LiquidityPoolAccountable_init(lender_, market_, token_, addonTreasury_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param lender_ The address of the liquidity pool lender.
    /// @param market_ The address of the lending market.
    /// @param token_ The address of the token.
    /// @param addonTreasury_ TODO
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function __LiquidityPoolAccountable_init(
        address lender_,
        address market_,
        address token_,
        address addonTreasury_
    ) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlExt_init_unchained();
        __Pausable_init_unchained();
        __LiquidityPoolAccountable_init_unchained(lender_, market_, token_, addonTreasury_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param lender_ The address of the liquidity pool lender.
    /// @param market_ The address of the lending market.
    /// @param token_ The address of the token.
    /// @param addonTreasury_ TODO.
    /// See details https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable.
    function __LiquidityPoolAccountable_init_unchained(
        address lender_,
        address market_,
        address token_,
        address addonTreasury_
    ) internal onlyInitializing {
        if (lender_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (token_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _grantRole(OWNER_ROLE, lender_);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(PAUSER_ROLE, OWNER_ROLE);

        _market = market_;
        _token = token_;

        if (addonTreasury_ != address(0)) {
            _setAddonTreasury(addonTreasury_);
        }
    }

    // -------------------------------------------- //
    //  Pauser functions                            //
    // -------------------------------------------- //

    /// @dev Pauses the contract.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @dev Unpauses the contract.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // -------------------------------------------- //
    //  Owner functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function deposit(uint256 amount) external onlyRole(OWNER_ROLE) {
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20 underlyingToken = IERC20(_token);

        if (underlyingToken.allowance(address(this), _market) == 0) {
            underlyingToken.approve(_market, type(uint256).max);
        }

        _borrowableBalance += amount.toUint64();
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(amount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function withdraw(uint256 borrowableAmount, uint256 addonAmount) external onlyRole(OWNER_ROLE) {
        if (borrowableAmount == 0 && addonAmount == 0) {
            revert Error.InvalidAmount();
        }

        if (_borrowableBalance < borrowableAmount) {
            revert InsufficientBalance();
        }
        if (_addonsBalance < addonAmount) {
            revert InsufficientBalance();
        }

        _borrowableBalance -= borrowableAmount.toUint64();
        _addonsBalance -= addonAmount.toUint64();

        IERC20(_token).safeTransfer(msg.sender, borrowableAmount + addonAmount);

        emit Withdrawal(borrowableAmount, addonAmount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function rescue(address token_, uint256 amount) external onlyRole(OWNER_ROLE) {
        if (token_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20(token_).safeTransfer(msg.sender, amount);

        emit Rescue(token_, amount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function setAddonTreasury(address newTreasury) external onlyRole(OWNER_ROLE) {
        _setAddonTreasury(newTreasury);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function setAddonActionKind(AddonActionKind newKind) external onlyRole(OWNER_ROLE) {
        _setAddonActionKind(newKind);
    }

    // -------------------------------------------- //
    //  Admin functions                             //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external whenNotPaused onlyRole(ADMIN_ROLE) {
        if (loanIds.length != amounts.length) {
            revert Error.ArrayLengthMismatch();
        }

        emit AutoRepayment(loanIds.length);

        ILendingMarket lendingMarket = ILendingMarket(_market);
        for (uint256 i = 0; i < loanIds.length; i++) {
            lendingMarket.repayLoan(loanIds[i], amounts[i]);
        }
    }

    // -------------------------------------------- //
    //  Market functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanTaken(uint256 loanId) external whenNotPaused onlyMarket returns (bool) {
        Loan.State memory loan = ILendingMarket(_market).getLoanState(loanId);
        _borrowableBalance -= loan.borrowAmount + loan.addonAmount;
        _collectAddon(loan.addonAmount);
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket returns (bool) {
        loanId; // To prevent compiler warning about unused variable
        _borrowableBalance += amount.toUint64();
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanRevocation(uint256 loanId) external whenNotPaused onlyMarket returns (bool) {
        Loan.State memory loan = ILendingMarket(_market).getLoanState(loanId);
        if (loan.borrowAmount > loan.repaidAmount) {
            _borrowableBalance = _borrowableBalance + (loan.borrowAmount - loan.repaidAmount) + loan.addonAmount;
        } else {
            _borrowableBalance = _borrowableBalance - (loan.repaidAmount - loan.borrowAmount) + loan.addonAmount;
        }
        _revokeAddon(loan.addonAmount);
        return true;
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function getBalances() external view returns (uint256, uint256) {
        return (_borrowableBalance, _addonsBalance);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /// @inheritdoc ILiquidityPool
    function market() external view returns (address) {
        return _market;
    }

    /// @inheritdoc ILiquidityPool
    function token() external view returns (address) {
        return _token;
    }

    /// @dev ILiquidityPool
    function addonTreasury() external view returns (address) {
        return _config.addonTreasury;
    }

    /// @dev ILiquidityPool
    function addonActionKind() external view returns (AddonActionKind) {
        return _config.addonActionKind;
    }

    // -------------------------------------------- //
    //  Pure functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPool
    function proveLiquidityPool() external pure {}

    // -------------------------------------------- //
    //  Internal functions                          //
    // -------------------------------------------- //

    /// @dev TODO
    function _setAddonTreasury(address newTreasury) internal {
        address oldTreasury = _config.addonTreasury;
        if (oldTreasury == newTreasury) {
            revert Error.AlreadyConfigured();
        }
        emit AddonTreasuryChanged(newTreasury, oldTreasury);
        _config.addonTreasury = newTreasury;
    }

    /// @dev TODO
    function _setAddonActionKind(AddonActionKind newKind) internal {
        AddonActionKind oldKind = _config.addonActionKind;
        if (oldKind == newKind) {
            revert Error.AlreadyConfigured();
        }
        if (newKind == AddonActionKind.Transfer) {
            address _addonTreasury = _config.addonTreasury;
            _checkAddonTreasuryAddress(_addonTreasury);
            _checkAddonTreasuryAllowance(_addonTreasury);
        }
        if (newKind == AddonActionKind.Retention) {
            revert AddonActionKindSwitchProhibited();
        }
        emit AddonActionKindChanged(newKind, oldKind);
        _config.addonActionKind = newKind;
    }

    /// @dev TODO
    function _collectAddon(uint64 addonAmount) internal {
        if (_config.addonActionKind == AddonActionKind.Retention) {
            _addonsBalance += addonAmount;
        } else {
            address _addonTreasury = _config.addonTreasury;
            _checkAddonTreasuryAddress(_addonTreasury);
            IERC20(_token).safeTransfer(_addonTreasury, addonAmount);
        }
    }

    /// @dev TODO
    function _revokeAddon(uint64 addonAmount) internal {
        if (_config.addonActionKind == AddonActionKind.Retention) {
            _addonsBalance -= addonAmount;
        } else {
            address _addonTreasury = _config.addonTreasury;
            _checkAddonTreasuryAddress(_addonTreasury);
            IERC20(_token).safeTransferFrom(_addonTreasury, address(this), addonAmount);
        }
    }

    /// @dev TODO
    function _checkAddonTreasuryAddress(address _addonTreasury) internal pure {
        if (_addonTreasury == address(0)) {
            revert AddonTreasuryAddressZero();
        }
    }

    function _checkAddonTreasuryAllowance(address _addonTreasury) internal view {
        uint256 allowance = IERC20(_token).allowance(_addonTreasury, address(this));
        if (allowance == 0) {
            revert AddonTreasuryInsufficientAllowance();
        }
    }
}

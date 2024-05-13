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


/// @title LiquidityPoolAccountable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the accountable liquidity pool contract.
contract LiquidityPoolAccountable is AccessControlExtUpgradeable, PausableUpgradeable, ILiquidityPoolAccountable {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @dev The role of this contract owner.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev The role of this contract admin.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev The role of this contract pauser.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @dev The address of the lending market.
    address internal _market;

    /// @dev The mapping of a loan identifier to a credit line.
    mapping(uint256 => address) internal _creditLines;

    /// @dev Mapping of a credit line to its token balance.
    mapping(address => CreditLineBalance) internal _creditLineBalances;

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

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
    function initialize(address lender_, address market_) external initializer {
        __LiquidityPoolAccountable_init(lender_, market_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param lender_ The address of the liquidity pool lender.
    /// @param market_ The address of the lending market.
    function __LiquidityPoolAccountable_init(address lender_, address market_) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlExt_init_unchained();
        __Pausable_init_unchained();
        __LiquidityPoolAccountable_init_unchained(lender_, market_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param lender_ The address of the liquidity pool lender.
    /// @param market_ The address of the lending market.
    function __LiquidityPoolAccountable_init_unchained(address lender_, address market_) internal onlyInitializing {
        if (lender_ == address(0)) {
            revert Error.ZeroAddress();
        }
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _grantRole(OWNER_ROLE, lender_);
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(PAUSER_ROLE, OWNER_ROLE);

        _market = market_;
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
    function deposit(address creditLine, uint256 amount) external onlyRole(OWNER_ROLE) {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20 token = IERC20(ICreditLine(creditLine).token());
        if (token.allowance(address(this), _market) == 0) {
            token.approve(_market, type(uint256).max);
        }

        _creditLineBalances[creditLine].borrowable += amount.toUint64();
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(creditLine, amount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function withdraw(address creditLine, uint256 borrowableAmount, uint256 addonAmount) external onlyRole(OWNER_ROLE) {
        if (creditLine == address(0)) {
            revert Error.ZeroAddress();
        }
        if (borrowableAmount == 0 && addonAmount == 0) {
            revert Error.InvalidAmount();
        }

        CreditLineBalance storage balance = _creditLineBalances[creditLine];
        if (balance.borrowable < borrowableAmount) {
            revert InsufficientBalance();
        }
        if (balance.addons < addonAmount) {
            revert InsufficientBalance();
        }

        balance.borrowable -= borrowableAmount.toUint64();
        balance.addons -= addonAmount.toUint64();

        IERC20(ICreditLine(creditLine).token()).safeTransfer(msg.sender, borrowableAmount + addonAmount);

        emit Withdrawal(creditLine, borrowableAmount, addonAmount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function rescue(address token, uint256 amount) external onlyRole(OWNER_ROLE) {
        if (token == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Rescue(token, amount);
    }

    // -------------------------------------------- //
    //  Admin functions                             //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external onlyRole(ADMIN_ROLE) {
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
    function onBeforeLoanTaken(
        uint256 loanId,
        address creditLine
    ) external view whenNotPaused onlyMarket returns (bool) {
        loanId; // To prevent compiler warning about unused variable
        creditLine; // To prevent compiler warning about unused variable
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket returns (bool) {
        Loan.State memory loan = ILendingMarket(_market).getLoanState(loanId);
        CreditLineBalance storage balance = _creditLineBalances[creditLine];
        balance.borrowable -= loan.borrowAmount + loan.addonAmount;
        balance.addons += loan.addonAmount;

        _creditLines[loanId] = creditLine;

        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanPayment(uint256 loanId, uint256 amount) external view whenNotPaused onlyMarket returns (bool) {
        loanId; // To prevent compiler warning about unused variable
        amount; // To prevent compiler warning about unused variable
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket returns (bool) {
        address creditLine = _creditLines[loanId];
        if (creditLine != address(0)) {
            _creditLineBalances[creditLine].borrowable += amount.toUint64();
        }

        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanRevocation(uint256 loanId) external view whenNotPaused onlyMarket returns (bool) {
        loanId; // To prevent compiler warning about unused variable
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanRevocation(uint256 loanId) external whenNotPaused onlyMarket returns (bool) {
        address creditLine = _creditLines[loanId];

        if (creditLine != address(0)) {
            CreditLineBalance storage balance = _creditLineBalances[creditLine];
            Loan.State memory loan = ILendingMarket(_market).getLoanState(loanId);
            if (loan.borrowAmount > loan.repaidAmount) {
                balance.borrowable = balance.borrowable + (loan.borrowAmount - loan.repaidAmount) + loan.addonAmount;
            } else if (loan.borrowAmount != loan.repaidAmount) {
                balance.borrowable = balance.borrowable - (loan.repaidAmount - loan.borrowAmount) + loan.addonAmount;
            }
            balance.addons -= loan.addonAmount;
        }

        return true;
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function getCreditLineBalance(address creditLine) external view returns (CreditLineBalance memory) {
        return _creditLineBalances[creditLine];
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function getCreditLine(uint256 loanId) external view returns (address) {
        return _creditLines[loanId];
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /// @inheritdoc ILiquidityPool
    function market() external view returns (address) {
        return _market;
    }
}

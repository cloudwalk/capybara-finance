// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Loan } from "../libraries/Loan.sol";
import { Error } from "../libraries/Error.sol";

import { ICreditLine } from "../interfaces/core/ICreditLine.sol";
import { ILendingMarket } from "../interfaces/core/ILendingMarket.sol";
import { ILiquidityPool } from "../interfaces/core/ILiquidityPool.sol";
import { ILiquidityPoolAccountable } from "../interfaces/ILiquidityPoolAccountable.sol";

/// @title LiquidityPoolAccountable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Implementation of the accountable liquidity pool contract.
contract LiquidityPoolAccountable is OwnableUpgradeable, PausableUpgradeable, ILiquidityPoolAccountable {
    using SafeERC20 for IERC20;

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    /// @dev The address of the lending market.
    address internal _market;

    /// @dev The mapping of account to admin status.
    mapping(address => bool) internal _admins;

    /// @dev The mapping of loan identifier to credit line.
    mapping(uint256 => address) internal _creditLines;

    /// @dev Mapping of credit line to its token balance.
    mapping(address => uint256) internal _creditLineBalances;

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the token source balance is zero.
    error ZeroBalance();

    /// @notice Thrown when the token source balance is insufficient.
    error InsufficientBalance();

    // -------------------------------------------- //
    //  Modifiers                                   //
    // -------------------------------------------- //

    /// @notice Throws if called by any account other than the lending market.
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    /// @notice Throws if called by any account other than the admin.
    modifier onlyAdmin() {
        if (!_admins[msg.sender]) {
            revert Error.Unauthorized();
        }
        _;
    }

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @notice Initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    /// @param lender_ The address of the lender.
    function initialize(address market_, address lender_) external initializer {
        __LiquidityPoolAccountable_init(market_, lender_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    /// @param lender_ The address of the lender.
    function __LiquidityPoolAccountable_init(address market_, address lender_) internal onlyInitializing {
        __Ownable_init_unchained(lender_);
        __Pausable_init_unchained();
        __LiquidityPoolAccountable_init_unchained(market_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    function __LiquidityPoolAccountable_init_unchained(address market_) internal onlyInitializing {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
    }

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

    /// @inheritdoc ILiquidityPoolAccountable
    function configureAdmin(address admin, bool isAdmin) external onlyOwner {
        if (admin == address(0)) {
            revert Error.ZeroAddress();
        }
        if (_admins[admin] == isAdmin) {
            revert Error.AlreadyConfigured();
        }

        _admins[admin] = isAdmin;

        emit AdminConfigured(admin, isAdmin);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function deposit(address creditLine, uint256 amount) external onlyOwner {
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

        _creditLineBalances[creditLine] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositMade(creditLine, amount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function withdraw(address tokenSource, uint256 amount) external onlyOwner {
        if (tokenSource == address(0)) {
            revert Error.ZeroAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        // Withdraw credit line balance
        uint256 balance = _creditLineBalances[tokenSource];
        if (balance != 0) {
            if (balance < amount) {
                revert InsufficientBalance();
            }
            _creditLineBalances[tokenSource] -= amount;
            IERC20(ICreditLine(tokenSource).token()).safeTransfer(msg.sender, amount);
            emit WithdrawalMade(tokenSource, amount);
            return;
        }

        // Withdraw token balance
        bytes memory data = abi.encodeWithSelector(IERC20.balanceOf.selector, address(this));
        (bool success, bytes memory returnData) = tokenSource.staticcall(data);
        if (success && returnData.length == 32) {
            balance = abi.decode(returnData, (uint256));
            if (balance < amount) {
                revert InsufficientBalance();
            }
            IERC20(tokenSource).safeTransfer(msg.sender, amount);
            emit WithdrawalMade(tokenSource, amount);
            return;
        }

        // Revert with zero balance error
        revert ZeroBalance();
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function autoRepay(uint256[] memory loanIds, uint256[] memory amounts) external onlyAdmin {
        if (loanIds.length != amounts.length) {
            revert Error.ArrayLengthMismatch();
        }

        emit AutoRepaymentInitiated(loanIds.length);

        ILendingMarket market = ILendingMarket(_market);
        for (uint256 i = 0; i < loanIds.length; i++) {
            market.repayLoan(loanIds[i], amounts[i]);
        }
    }

    // -------------------------------------------- //
    //  Market functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket returns (bool) {
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket returns (bool) {
        _creditLineBalances[creditLine] -= ILendingMarket(_market).getLoanState(loanId).initialBorrowAmount;
        _creditLines[loanId] = creditLine;

        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket returns (bool) {
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket returns (bool) {
        address creditLine = _creditLines[loanId];
        if (creditLine != address(0)) {
            _creditLineBalances[creditLine] += amount;
        }

        return true;
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

    /// @inheritdoc ILiquidityPoolAccountable
    function getTokenBalance(address tokenSource) external view returns (uint256) {
        // Return credit line balance
        uint256 balance = _creditLineBalances[tokenSource];
        if (balance != 0) {
            return balance;
        }

        // Return token balance
        bytes memory data = abi.encodeWithSelector(IERC20.balanceOf.selector, address(this));
        (bool success, bytes memory returnData) = tokenSource.staticcall(data);
        if (success && returnData.length == 32) {
            return abi.decode(returnData, (uint256));
        }

        return 0;
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function getCreditLine(uint256 loanId) external view returns (address) {
        return _creditLines[loanId];
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function isAdmin(address account) external view returns (bool) {
        return _admins[account];
    }

    /// @inheritdoc ILiquidityPool
    function market() external view returns (address) {
        return _market;
    }

    /// @inheritdoc ILiquidityPool
    function lender() external view returns (address) {
        return owner();
    }

    /// @inheritdoc ILiquidityPool
    function kind() external pure returns (uint16) {
        return 1;
    }
}

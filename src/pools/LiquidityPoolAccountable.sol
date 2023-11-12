// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Loan} from "../libraries/Loan.sol";
import {Error} from "../libraries/Error.sol";

import {ICreditLine} from "../interfaces/core/ICreditLine.sol";
import {ILiquidityPool} from "../interfaces/core/ILiquidityPool.sol";
import {ILiquidityPoolAccountable} from "../interfaces/ILiquidityPoolAccountable.sol";
import {ILendingMarket} from "../interfaces/core/ILendingMarket.sol";

/// @title LiquidityPoolAccountable contract
/// @notice Implementation of the accountable liquidity pool contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolAccountable is Ownable, Pausable, ILiquidityPool, ILiquidityPoolAccountable {
    using SafeERC20 for IERC20;

    /************************************************
     *  Storage
     ***********************************************/

    /// @notice The address of the associated lending market
    address internal immutable _market;

    /// @notice The mapping of loan identifier to associated credit line
    mapping(uint256 => address) internal _creditLines;

    /// @notice Mapping of credit line address to its token balance
    mapping(address => uint256) internal _creditLineBalances;

    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the token source balance is zero
    error ZeroBalance();

    /// @notice Thrown when the token source balance is insufficient
    error InsufficientBalance();

    /************************************************
     *  MODIFIERS
     ***********************************************/

    /// @notice Throws if called by any account other than the market
    modifier onlyMarket() {
        if (msg.sender != _market) {
            revert Error.Unauthorized();
        }
        _;
    }

    /************************************************
     *  Constructor
     ***********************************************/

    /// @notice Contract constructor
    /// @param market_ The address of the associated lending market
    /// @param lender_ The address of the associated lender
    constructor(address market_, address lender_) Ownable(lender_) {
        if (market_ == address(0)) {
            revert Error.InvalidAddress();
        }
        if (lender_ == address(0)) {
            revert Error.InvalidAddress();
        }

        _market = market_;
    }

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

    /// @inheritdoc ILiquidityPoolAccountable
    function deposit(address creditLine, uint256 amount) external onlyOwner {
        if (creditLine == address(0)) {
            revert Error.InvalidAddress();
        }
        if (amount == 0) {
            revert Error.InvalidAmount();
        }

        IERC20 token = IERC20(_creditLineToken(creditLine));

        if (token.allowance(address(this), _market) == 0) {
            token.approve(_market, type(uint256).max);
        }

        _creditLineBalances[creditLine] += amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(creditLine, amount);
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function withdraw(address tokenSource, uint256 amount) external onlyOwner {
        if (tokenSource == address(0)) {
            revert Error.InvalidAddress();
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
            IERC20(_creditLineToken(tokenSource)).safeTransfer(msg.sender, amount);
            emit Withdraw(tokenSource, amount);
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
            emit Withdraw(tokenSource, amount);
            return;
        } else { }

        // Revert with zero balance error
        revert ZeroBalance();
    }

    /************************************************
     *  MARKET FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket returns (bool) {
        return true;
    }

    /// @inheritdoc ILiquidityPool
    function onAfterLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket returns (bool) {
        _creditLineBalances[creditLine] -= _loanInitialBorrowAmount(loanId);
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
            return true;
        } else {
            return true;
        }
    }

    /************************************************
     *  VIEW FUNCTIONS
     ***********************************************/

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
        } else {
            return 0;
        }
    }

    /// @inheritdoc ILiquidityPoolAccountable
    function getCreditLine(uint256 loanId) external view returns (address) {
        return _creditLines[loanId];
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

    function _loanInitialBorrowAmount(uint256 loanId) internal virtual view returns (uint256) {
        return ILendingMarket(_market).getLoanStored(loanId).initialBorrowAmount;
    }

    function _creditLineToken(address creditLine) internal virtual view returns (address) {
        return ICreditLine(creditLine).token();
    }
}

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
contract LiquidityPoolAccountable is Ownable, Pausable, ILiquidityPoolAccountable, ILiquidityPool {
    using SafeERC20 for IERC20;

    /************************************************
     *  STORAGE
     ***********************************************/

    /// @notice The address of the associated lending market
    address internal immutable _market;

    /// @notice The mapping of loan identifier to associated credit line
    mapping(uint256 => address) internal _creditLines;

    /// @notice Mapping of credit line address to its token balance
    mapping(address => uint256) internal _creditLineBalances;

    /// @notice Mapping of non credit line to its token balance
    mapping(address => uint256) internal _nonCreditLineBalances;

    /************************************************
     *  ERRORS
     ***********************************************/

    /// @notice Thrown when the token source is not expected
    error UnexpectedTokenSource();

    /// @notice Thrown when the token balance is not enough
    error OutOfTokenBalance();

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
     *  CONSTRUCTOR
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
     *  OWNER FUNCTIONS
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

        address token = ICreditLine(creditLine).token();

        if (IERC20(token).allowance(address(this), _market) == 0) {
            IERC20(token).approve(_market, type(uint256).max);
        }

        _creditLineBalances[creditLine] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

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

        // withdraw from credit line balance
        uint256 balance = _creditLineBalances[tokenSource];
        if (balance != 0) {
            if (balance < amount) {
                revert OutOfTokenBalance();
            }

            _creditLineBalances[tokenSource] -= amount;

            address token = ICreditLine(tokenSource).token();
            IERC20(token).safeTransfer(msg.sender, amount);

            emit Withdraw(tokenSource, amount);

            return;
        }

        // withdraw from non credit line balance
        balance = _nonCreditLineBalances[tokenSource];
        if (balance != 0) {
            if (balance < amount) {
                revert OutOfTokenBalance();
            }

            _nonCreditLineBalances[tokenSource] -= amount;

            IERC20(tokenSource).safeTransfer(msg.sender, amount);

            emit Withdraw(tokenSource, amount);

            return;
        }

        // rescue tokens
        balance = IERC20(tokenSource).balanceOf(address(this));
        if (balance != 0) {
            if (balance < amount) {
                revert OutOfTokenBalance();
            }

            IERC20(tokenSource).safeTransfer(msg.sender, amount);

            emit Withdraw(tokenSource, amount);

            return;
        }

        // revert
        revert UnexpectedTokenSource();
    }

    /************************************************
     *  MARKET FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket {}

    /// @inheritdoc ILiquidityPool
    function onAfterLoanTaken(uint256 loanId, address creditLine) external whenNotPaused onlyMarket {
        Loan.State memory loan = ILendingMarket(_market).getLoanStored(loanId);
        _creditLineBalances[creditLine] -= loan.initialBorrowAmount;
        _creditLines[loanId] = creditLine;
    }

    /// @inheritdoc ILiquidityPool
    function onBeforeLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket {}

    /// @inheritdoc ILiquidityPool
    function onAfterLoanPayment(uint256 loanId, uint256 amount) external whenNotPaused onlyMarket {
        address creditLine = _creditLines[loanId];
        if (creditLine != address(0)) {
            _creditLineBalances[creditLine] += amount;
        } else {
            Loan.State memory loan = ILendingMarket(_market).getLoanStored(loanId);
            _nonCreditLineBalances[loan.token] += amount;
        }
    }

    /************************************************
     *  VIEW FUNCTIONS
     ***********************************************/

    /// @inheritdoc ILiquidityPoolAccountable
    function getTokenBalance(address tokenSource) external view returns (uint256) {
        if (tokenSource == address(0)) {
            revert Error.InvalidAddress();
        }

        // credit line balance
        uint256 balance = _creditLineBalances[tokenSource];
        if (balance != 0) {
            return balance;
        }

        // non credit line balance
        balance = _nonCreditLineBalances[tokenSource];
        if (balance != 0) {
            return balance;
        }

        // native token balance
        balance = IERC20(tokenSource).balanceOf(address(this));
        if (balance != 0) {
            return balance;
        }

        // revert
        revert UnexpectedTokenSource();
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
}

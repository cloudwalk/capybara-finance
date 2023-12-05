// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Error} from "../libraries/Error.sol";
import {ILiquidityPool} from "../interfaces/core/ILiquidityPool.sol";

/// @title LiquidityPoolMock contract
/// @notice LiquidityPool mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolMock is ILiquidityPool {
    /************************************************
     *  Events
     ***********************************************/

    event OnBeforeTakeLoanCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterTakeLoanCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    /************************************************
     *  Storage variables
     ***********************************************/

    bool _onBeforeTakeLoanResult;
    bool _onAfterTakeLoanResult;

    bool _onBeforeLoanPaymentResult;
    bool _onAfterLoanPaymentResult;

    /************************************************
     *  ILiquidityPoolFactory functions
     ***********************************************/

    function onBeforeTakeLoan(uint256 loanId, address creditLine) external returns (bool) {
        emit OnBeforeTakeLoanCalled(loanId, creditLine);
        return _onBeforeTakeLoanResult;
    }

    function onAfterTakeLoan(uint256 loanId, address creditLine) external returns (bool) {
        emit OnAfterTakeLoanCalled(loanId, creditLine);
        return _onAfterTakeLoanResult;
    }

    function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnBeforeLoanPaymentCalled(loanId, repayAmount);
        return _onBeforeLoanPaymentResult;
    }

    function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnAfterLoanPaymentCalled(loanId, repayAmount);
        return _onAfterLoanPaymentResult;
    }

    function market() external pure returns (address) {
        revert Error.NotImplemented();
    }

    function lender() external pure returns (address) {
        revert Error.NotImplemented();
    }

    function kind() external pure returns (uint16) {
        revert Error.NotImplemented();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockOnBeforeTakeLoanResult(bool result) external {
        _onBeforeTakeLoanResult = result;
    }

    function mockOnAfterTakeLoanResult(bool result) external {
        _onAfterTakeLoanResult = result;
    }

    function mockOnBeforeLoanPaymentResult(bool result) external {
        _onBeforeLoanPaymentResult = result;
    }

    function mockOnAfterLoanPaymentResult(bool result) external {
        _onAfterLoanPaymentResult = result;
    }
}

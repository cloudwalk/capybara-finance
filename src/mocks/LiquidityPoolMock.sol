// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Error } from "../common/libraries/Error.sol";
import { ILiquidityPool } from "../common/interfaces/core/ILiquidityPool.sol";

/// @title LiquidityPoolMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Mock of the `LiquidityPool` contract used for testing.
contract LiquidityPoolMock is ILiquidityPool {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnBeforeLoanCancellationCalled(uint256 indexed loanId);
    event OnAfterLoanCancellationCalled(uint256 indexed loanId);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    bool private _onBeforeLoanTakenResult;
    bool private _onAfterLoanTakenResult;

    bool private _onBeforeLoanPaymentResult;
    bool private _onAfterLoanPaymentResult;

    bool private _onBeforeLoanCancellationResult;
    bool private _onAfterLoanCancellationResult;

    // -------------------------------------------- //
    //  ILiquidityPoolFactory functions             //
    // -------------------------------------------- //

    function onBeforeLoanTaken(uint256 loanId, address creditLine) external returns (bool) {
        emit OnBeforeLoanTakenCalled(loanId, creditLine);
        return _onBeforeLoanTakenResult;
    }

    function onAfterLoanTaken(uint256 loanId, address creditLine) external returns (bool) {
        emit OnAfterLoanTakenCalled(loanId, creditLine);
        return _onAfterLoanTakenResult;
    }

    function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnBeforeLoanPaymentCalled(loanId, repayAmount);
        return _onBeforeLoanPaymentResult;
    }

    function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnAfterLoanPaymentCalled(loanId, repayAmount);
        return _onAfterLoanPaymentResult;
    }

    function onBeforeLoanCancellation(uint256 loanId) external returns (bool) {
        emit OnBeforeLoanCancellationCalled(loanId);
        return _onBeforeLoanCancellationResult;
    }

    function onAfterLoanCancellation(uint256 loanId) external returns (bool) {
        emit OnAfterLoanCancellationCalled(loanId);
        return _onAfterLoanCancellationResult;
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

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockOnBeforeLoanTakenResult(bool result) external {
        _onBeforeLoanTakenResult = result;
    }

    function mockOnAfterLoanTakenResult(bool result) external {
        _onAfterLoanTakenResult = result;
    }

    function mockOnBeforeLoanPaymentResult(bool result) external {
        _onBeforeLoanPaymentResult = result;
    }

    function mockOnAfterLoanPaymentResult(bool result) external {
        _onAfterLoanPaymentResult = result;
    }

    function mockOnBeforeLoanCancellationResult(bool result) external {
        _onBeforeLoanCancellationResult = result;
    }

    function mockOnAfterLoanCancellationResult(bool result) external {
        _onAfterLoanCancellationResult = result;
    }
}

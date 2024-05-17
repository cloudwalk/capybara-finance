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

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    event OnBeforeLoanRevocationCalled(uint256 indexed loanId);
    event OnAfterLoanRevocationCalled(uint256 indexed loanId);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    bool private _onBeforeLoanTakenResult;

    bool private _onBeforeLoanPaymentResult;
    bool private _onAfterLoanPaymentResult;

    bool private _onBeforeLoanRevocationResult;
    bool private _onAfterLoanRevocationResult;

    // -------------------------------------------- //
    //  ILiquidityPool functions                    //
    // -------------------------------------------- //

    function onBeforeLoanTaken(uint256 loanId, address creditLine) external returns (bool) {
        emit OnBeforeLoanTakenCalled(loanId, creditLine);
        return _onBeforeLoanTakenResult;
    }

    function onBeforeLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnBeforeLoanPaymentCalled(loanId, repayAmount);
        return _onBeforeLoanPaymentResult;
    }

    function onAfterLoanPayment(uint256 loanId, uint256 repayAmount) external returns (bool) {
        emit OnAfterLoanPaymentCalled(loanId, repayAmount);
        return _onAfterLoanPaymentResult;
    }

    function onBeforeLoanRevocation(uint256 loanId) external returns (bool) {
        emit OnBeforeLoanRevocationCalled(loanId);
        return _onBeforeLoanRevocationResult;
    }

    function onAfterLoanRevocation(uint256 loanId) external returns (bool) {
        emit OnAfterLoanRevocationCalled(loanId);
        return _onAfterLoanRevocationResult;
    }

    function market() external pure returns (address) {
        revert Error.NotImplemented();
    }

    function lender() external pure returns (address) {
        revert Error.NotImplemented();
    }

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockOnBeforeLoanTakenResult(bool result) external {
        _onBeforeLoanTakenResult = result;
    }

    function mockOnBeforeLoanPaymentResult(bool result) external {
        _onBeforeLoanPaymentResult = result;
    }

    function mockOnAfterLoanPaymentResult(bool result) external {
        _onAfterLoanPaymentResult = result;
    }

    function mockOnBeforeLoanRevocationResult(bool result) external {
        _onBeforeLoanRevocationResult = result;
    }

    function mockOnAfterLoanRevocationResult(bool result) external {
        _onAfterLoanRevocationResult = result;
    }
}

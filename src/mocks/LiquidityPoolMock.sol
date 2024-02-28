// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Error } from "../libraries/Error.sol";
import { ILiquidityPool } from "../interfaces/core/ILiquidityPool.sol";

/// @title LiquidityPoolMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Mock of the `LiquidityPool` contract used for testing.
contract LiquidityPoolMock is ILiquidityPool {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event OnBeforeLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);
    event OnAfterLoanTakenCalled(uint256 indexed loanId, address indexed creditLine);

    event OnBeforeLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);
    event OnAfterLoanPaymentCalled(uint256 indexed loanId, uint256 indexed repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    bool _onBeforeLoanTakenResult;
    bool _onAfterLoanTakenResult;

    bool _onBeforeLoanPaymentResult;
    bool _onAfterLoanPaymentResult;

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
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Loan } from "../common/libraries/Loan.sol";
import { Error } from "../common/libraries/Error.sol";
import { ILendingMarket } from "../common/interfaces/core/ILendingMarket.sol";

/// @title LendingMarketMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Mock of the `LendingMarket` contract used for testing.
contract LendingMarketMock is ILendingMarket {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event RepayLoanCalled(uint256 indexed loanId, uint256 repayAmount);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    mapping(uint256 => Loan.State) private _loanStates;

    // -------------------------------------------- //
    //  ILendingMarket functions                    //
    // -------------------------------------------- //

    function registerCreditLine(address creditLine) external {
        creditLine; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function registerLiquidityPool(address liquidityPool) external {
        liquidityPool; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function createProgram(address creditLine, address liquidityPool) external {
        creditLine; // To prevent compiler warning about unused variable
        liquidityPool; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function updateProgram(uint32 programId, address creditLine, address liquidityPool) external {
        programId; // To prevent compiler warning about unused variable
        creditLine; // To prevent compiler warning about unused variable
        liquidityPool; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function takeLoanFor(
        address borrower,
        uint32 programId,
        uint256 borrowAmount,
        uint256 addonAmount,
        uint256 durationInPeriods
    ) external pure returns (uint256) {
        borrower; // To prevent compiler warning about unused variable
        programId; // To prevent compiler warning about unused variable
        borrowAmount; // To prevent compiler warning about unused variable
        addonAmount; // To prevent compiler warning about unused variable
        durationInPeriods; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function takeLoan(
        uint32 programId,
        uint256 borrowAmount,
        uint256 durationInPeriods
    ) external pure returns (uint256) {
        programId; // To prevent compiler warning about unused variable
        borrowAmount; // To prevent compiler warning about unused variable
        durationInPeriods; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function repayLoan(uint256 loanId, uint256 repayAmount) external {
        loanId; // To prevent compiler warning about unused variable
        repayAmount; // To prevent compiler warning about unused variable
        emit RepayLoanCalled(loanId, repayAmount);
    }

    function freeze(uint256 loanId) external pure {
        loanId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function unfreeze(uint256 loanId) external pure {
        loanId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function revokeLoan(uint256 loanId) external pure {
        loanId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external pure {
        loanId; // To prevent compiler warning about unused variable
        newDurationInPeriods; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external pure {
        loanId; // To prevent compiler warning about unused variable
        newInterestRate; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external pure {
        loanId; // To prevent compiler warning about unused variable
        newInterestRate; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function configureAlias(address account, bool isAlias) external pure {
        account; // To prevent compiler warning about unused variable
        isAlias; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getCreditLineLender(address creditLine) external pure returns (address) {
        creditLine; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getLiquidityPoolLender(address lender) external pure returns (address) {
        lender; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getProgramLender(uint32 programId) external view returns (address) {
        programId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getProgramCreditLine(uint32 programId) external view returns (address) {
        programId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getProgramLiquidityPool(uint32 programId) external view returns (address) {
        programId; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function getLoanState(uint256 loanId) external view returns (Loan.State memory) {
        return _loanStates[loanId];
    }

    function getLoanPreview(uint256 loanId, uint256 timestamp) external pure returns (Loan.Preview memory) {
        loanId; // To prevent compiler warning about unused variable
        timestamp; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function isLenderOrAlias(uint256 loanId, address account) external pure returns (bool) {
        loanId; // To prevent compiler warning about unused variable
        account; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function hasAlias(address lender, address account) external pure returns (bool) {
        lender; // To prevent compiler warning about unused variable
        account; // To prevent compiler warning about unused variable
        revert Error.NotImplemented();
    }

    function interestRateFactor() external view returns (uint256) {
        revert Error.NotImplemented();
    }

    function periodInSeconds() external view returns (uint256) {
        revert Error.NotImplemented();
    }

    function timeOffset() external view returns (uint256, bool) {
        revert Error.NotImplemented();
    }

    function loanCounter() external view returns (uint256) {
        revert Error.NotImplemented();
    }

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockLoanState(uint256 loanId, Loan.State memory state) external {
        _loanStates[loanId] = state;
    }
}

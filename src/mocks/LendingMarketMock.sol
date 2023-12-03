// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Loan} from "../libraries/Loan.sol";
import {ILendingMarket} from "../interfaces/core/ILendingMarket.sol";

/// @title LendingMarket contract
/// @notice Lending market mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketMock is ILendingMarket {
    /************************************************
     *  Events
     ***********************************************/

    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);

    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);

    error NotImplemented();

    /************************************************
     *  Storage variables
     ***********************************************/

    mapping(uint256 => Loan.State) _loanState;

    /************************************************
     *  ILendingMarket functions
     ***********************************************/

    function takeLoan(address creditLine, uint256 amount) external returns (uint256) {
        revert NotImplemented();
    }

    function repayLoan(uint256 loanId, uint256 amount) external {
        revert NotImplemented();
    }

    function freeze(uint256 loanId) external {
        revert NotImplemented();
    }

    function unfreeze(uint256 loanId) external {
        revert NotImplemented();
    }

    function updateLoanDuration(uint256 loanId, uint256 newDurationInPeriods) external {
        revert NotImplemented();
    }

    function updateLoanMoratorium(uint256 loanId, uint256 newMoratoriumInPeriods) external {
        revert NotImplemented();
    }

    function updateLoanInterestRatePrimary(uint256 loanId, uint256 newInterestRate) external {
        revert NotImplemented();
    }

    function updateLoanInterestRateSecondary(uint256 loanId, uint256 newInterestRate) external {
        revert NotImplemented();
    }

    function updateLender(address creditLine, address newLender) external {
        revert NotImplemented();
    }

    function registerCreditLine(address lender, address creditLine) external {
        emit RegisterCreditLineCalled(lender, creditLine);
    }

    function registerLiquidityPool(address lender, address liquidityPool) external {
        emit RegisterLiquidityPoolCalled(lender, liquidityPool);
    }

    function getLender(address creditLine) external view returns (address) {
        revert NotImplemented();
    }

    function getLiquidityPool(address lender) external view returns (address) {
        revert NotImplemented();
    }

    function getLoan(uint256 loanId) external view returns (Loan.State memory) {
        return _loanState[loanId];
    }

    function getLoanPreview(uint256 loanId, uint256 repayAmount, uint256 repayDate)
        external
        view
        returns (Loan.State memory)
    {
        revert NotImplemented();
    }

    function getOutstandingBalance(uint256 loanId) external view returns (uint256) {
        revert NotImplemented();
    }

    function getCurrentPeriodDate(uint256 loanId) external view returns (uint256) {
        revert NotImplemented();
    }

    function registry() external view returns (address) {
        revert NotImplemented();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockLoanState(uint256 loanId, Loan.State memory state) external {
        _loanState[loanId] = state;
    }
}

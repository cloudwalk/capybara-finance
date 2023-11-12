// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Loan} from "./libraries/Loan.sol";
import {ILendingMarket} from "./interfaces/core/ILendingMarket.sol";

/// @title LendingMarket contract
/// @notice Implementation of the lending market contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketMock is ILendingMarket
{

    /************************************************
     *  EVENTS
     ***********************************************/

    /// registerCreditLine(lender, creditLine);

    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);

    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);

    error NotImplemented();

    /************************************************
     *  BORROWER FUNCTIONS
     ***********************************************/

    function takeLoan(address creditLine, uint256 amount) external {
        revert NotImplemented();
    }

    function repayLoan(uint256 loanId, uint256 amount) external {
        revert NotImplemented();
    }

    /************************************************
     *  LOAN HOLDER FUNCTIONS
     ***********************************************/


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

    /************************************************
     *  VIEW FUNCTIONS
     ***********************************************/

    function getLender(address creditLine) external view returns (address) {
        revert NotImplemented();
    }

    function getLiquidityPool(address lender) external view returns (address) {
        revert NotImplemented();
    }

    function getLoanStored(uint256 loanId) external view returns (Loan.State memory) {
        return _loanStateMock[loanId];
    }

    function getLoanCurrent(uint256 loanId) external view returns (Loan.Status, Loan.State memory) {
        revert NotImplemented();
    }

    mapping (uint256 => Loan.State) _loanStateMock;

    function mockLoanState(uint256 loanId, Loan.State memory state) external {
        _loanStateMock[loanId] = state;
    }
}

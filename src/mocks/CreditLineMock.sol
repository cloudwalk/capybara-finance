// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Loan} from "src/libraries/Loan.sol";
import {ICreditLine} from "src/interfaces/core/ICreditLine.sol";

/// @title CreditLineMock contract
/// @notice Credit line mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineMock is ICreditLine {
    /************************************************
     *  Errors
     ***********************************************/

    error NotImplement();

    /************************************************
     *  Storage variables
     ***********************************************/

    address private _tokenAddress;

    mapping(address => mapping(uint256 => Loan.Terms)) _loanTerms;

    /************************************************
     *  ICreditLine functions
     ***********************************************/

    function onLoanTaken(address borrower, uint256 amount) external returns (Loan.Terms memory terms) {
        return _loanTerms[borrower][amount];
    }

    function determineLoanTerms(address borrower, uint256 amount) external view returns (Loan.Terms memory terms) {
        return _loanTerms[borrower][amount];
    }

    function market() external view returns (address) {
        revert NotImplement();
    }

    function lender() external view returns (address) {
        revert NotImplement();
    }

    function token() external view returns (address) {
        return _tokenAddress;
    }

    function kind() external view returns (uint16) {
        revert NotImplement();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockTokenAddress(address tokenAddress) external {
        _tokenAddress = tokenAddress;
    }

    function mockLoanTerms(address borrower, uint256 amount, Loan.Terms memory terms) external {
        _loanTerms[borrower][amount] = terms;
    }
}

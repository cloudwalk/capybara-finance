// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Loan } from "../common/libraries/Loan.sol";
import { Error } from "../common/libraries/Error.sol";
import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";

/// @title CreditLineMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Mock of the `CreditLine` contract used for testing.
contract CreditLineMock is ICreditLine {
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    address private _tokenAddress;
    mapping(address => mapping(uint256 => Loan.Terms)) private _loanTerms;

    // -------------------------------------------- //
    //  ICreditLine functions                       //
    // -------------------------------------------- //

    function onBeforeLoanTaken(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods,
        uint256 loanId
    ) external view returns (Loan.Terms memory terms) {
        durationInPeriods; // To prevent compiler warning about unused variable
        loanId; // To prevent compiler warning about unused variable
        return _loanTerms[borrower][borrowAmount];
    }

    function determineLoanTerms(
        address borrower,
        uint256 borrowAmount,
        uint256 durationInPeriods
    ) external view returns (Loan.Terms memory terms) {
        durationInPeriods; // To prevent compiler warning about unused variable
        return _loanTerms[borrower][borrowAmount];
    }

    function market() external pure returns (address) {
        revert Error.NotImplemented();
    }

    function lender() external pure returns (address) {
        revert Error.NotImplemented();
    }

    function token() external view returns (address) {
        return _tokenAddress;
    }

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockTokenAddress(address tokenAddress) external {
        _tokenAddress = tokenAddress;
    }

    function mockLoanTerms(address borrower, uint256 amount, Loan.Terms memory terms) external {
        _loanTerms[borrower][amount] = terms;
    }
}

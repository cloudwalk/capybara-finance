// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Loan} from "../libraries/Loan.sol";
import {Error} from "../libraries/Error.sol";
import {ICreditLine} from "../interfaces/core/ICreditLine.sol";

/// @title CreditLineMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice CreditLine mock contract used for testing
contract CreditLineMock is ICreditLine {
    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    address private _tokenAddress;

    mapping(address => mapping(uint256 => Loan.Terms)) _loanTerms;

    // -------------------------------------------- //
    //  ICreditLine functions                       //
    // -------------------------------------------- //

    function onBeforeLoanTaken(address borrower, uint256 amount, uint256 loanId) external returns (Loan.Terms memory terms) {
        return _loanTerms[borrower][amount];
    }

    function determineLoanTerms(address borrower, uint256 amount) external view returns (Loan.Terms memory terms) {
        return _loanTerms[borrower][amount];
    }

    function market() external view returns (address) {
        revert Error.NotImplemented();
    }

    function lender() external view returns (address) {
        revert Error.NotImplemented();
    }

    function token() external view returns (address) {
        return _tokenAddress;
    }

    function kind() external view returns (uint16) {
        revert Error.NotImplemented();
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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";

import {ICreditLine} from "src/interfaces/core/ICreditLine.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";


contract CreditLineMock is ICreditLine {
    error NotImplement();

    address _token;

    function onLoanTaken(address borrower, uint256 amount) external returns (Loan.Terms memory terms) {
        revert NotImplement();
    }

    function determineLoanTerms(address borrower, uint256 amount) external view returns (Loan.Terms memory terms) {
        revert NotImplement();
    }

    function market() external view returns (address) {
        revert NotImplement();
    }

    function lender() external view returns (address) {
        revert NotImplement();
    }

    function token() external view returns (address) {
        return _token;
    }

    function kind() external view returns (uint16) {
        revert NotImplement();
    }

    // Mocks

    function mockToken(address token) external {
        _token = token;
    }
}

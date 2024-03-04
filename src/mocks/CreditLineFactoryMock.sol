// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Error } from "../libraries/Error.sol";
import { ICreditLineFactory } from "../interfaces/ICreditLineFactory.sol";

/// @title CreditLineFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Mock of the `CreditLineFactory` contract used for testing.
contract CreditLineFactoryMock is ICreditLineFactory {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event CreateCreditLineCalled(address indexed market, address indexed lender, address indexed token, uint16 kind, bytes data);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    address private _createdCreditLineAddress;

    // -------------------------------------------- //
    //  ICreditLineFactory functions                //
    // -------------------------------------------- //

    function createCreditLine(
        address market,
        address lender,
        address token,
        uint16 kind,
        bytes calldata data
    ) external returns (address creditLine) {
        emit CreateCreditLineCalled(market, lender, token, kind, data);
        return _createdCreditLineAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert Error.NotImplemented();
    }

    // -------------------------------------------- //
    //  Mock functions                              //
    // -------------------------------------------- //

    function mockCreatedCreditLineAddress(address creditLineAddress) external {
        _createdCreditLineAddress = creditLineAddress;
    }
}

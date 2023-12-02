// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ICreditLineFactory} from "src/interfaces/ICreditLineFactory.sol";

/// @title CreditLineFactoryMock contract
/// @notice Credit line factory mock contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryMock is ICreditLineFactory {

    /************************************************
     *  Events
     ***********************************************/

    event CreateCreditLineCalled(
        address indexed market,
        address indexed lender,
        uint16 indexed kind,
        bytes data
    );

    /************************************************
     *  Errors
     ***********************************************/

    error NotImplemented();

    /************************************************
     *  Storage variables
     ***********************************************/

    address private _creditLineAddress;

    /************************************************
     *  ICreditLineFactory functions
     ***********************************************/

    function createCreditLine(address market, address lender, uint16 kind, bytes calldata data)
        external
        returns (address creditLine)
    {
        emit CreateCreditLineCalled(market, lender, kind, data);
        return _creditLineAddress;
    }

    function supportedKinds() external pure override returns (uint16[] memory) {
        revert NotImplemented();
    }

    /************************************************
     *  Mock functions
     ***********************************************/

    function mockCreditLineAddress(address creditLineAddress) external {
        _creditLineAddress = creditLineAddress;
    }
}

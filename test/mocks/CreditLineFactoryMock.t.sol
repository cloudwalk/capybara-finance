// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Error} from "src/libraries/Error.sol";
import {CreditLineFactoryMock} from "src/mocks/CreditLineFactoryMock.sol";

/// @title CreditLineFactoryMockTest contract
/// @notice Contains tests for the CreditLineFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryMockTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event CreateCreditLineCalled(
        address indexed market, address indexed lender, address indexed token, uint16 kind, bytes data
    );

    /************************************************
     *  Storage variables
     ***********************************************/

    CreditLineFactoryMock public mock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        mock = new CreditLineFactoryMock();
    }

    /************************************************
     *  ICreditLineFactory functions
     ***********************************************/

    function test_createCreditLine() public {
        address creditLine = address(0x0);
        address market = address(0x1);
        address lender = address(0x2);
        address token = address(0x3);
        uint16 kind = 1;
        bytes memory data = "data";

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(market, lender, token, kind, data);
        creditLine = mock.createCreditLine(market, lender, token, kind, data);
        assertEq(creditLine, address(0x0));

        mock.mockCreditLineAddress(address(0x4));
        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(market, lender, token, kind, data);
        creditLine = mock.createCreditLine(market, lender, token, kind, data);
        assertEq(creditLine, address(0x4));
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

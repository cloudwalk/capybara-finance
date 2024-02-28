// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { Error } from "src/libraries/Error.sol";
import { CreditLineFactoryMock } from "src/mocks/CreditLineFactoryMock.sol";

/// @title CreditLineFactoryMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `CreditLineFactoryMock` contract.
contract CreditLineFactoryMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event CreateCreditLineCalled(
        address indexed market, address indexed lender, address indexed token, uint16 kind, bytes data
    );

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineFactoryMock public mock;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new CreditLineFactoryMock();
    }

    // -------------------------------------------- //
    //  ICreditLineFactory functions                //
    // -------------------------------------------- //

    function test_createCreditLine() public {
        address market = address(1);
        address lender = address(2);
        address token = address(3);
        uint16 kind = 1;
        bytes memory data = "data";

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(market, lender, token, kind, data);
        assertEq(mock.createCreditLine(market, lender, token, kind, data), address(0));

        address mockedCreditLineAddress = address(4);
        mock.mockCreatedCreditLineAddress(mockedCreditLineAddress);

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(market, lender, token, kind, data);
        assertEq(mock.createCreditLine(market, lender, token, kind, data), mockedCreditLineAddress);
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

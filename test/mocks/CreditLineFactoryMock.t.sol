// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

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

    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant CREDIT_LINE = address(bytes20(keccak256("credit_line")));
    uint16 public constant KIND = 1;
    bytes public constant DATA = "0x123ff";

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
        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(MARKET, LENDER, TOKEN, KIND, DATA);
        assertEq(mock.createCreditLine(MARKET, LENDER, TOKEN, KIND, DATA), address(0));

        mock.mockCreatedCreditLineAddress(CREDIT_LINE);

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateCreditLineCalled(MARKET, LENDER, TOKEN, KIND, DATA);
        assertEq(mock.createCreditLine(MARKET, LENDER, TOKEN, KIND, DATA), CREDIT_LINE);
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

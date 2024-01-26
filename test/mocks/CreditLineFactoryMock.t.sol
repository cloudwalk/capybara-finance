// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {CreditLineFactoryMock} from "src/mocks/CreditLineFactoryMock.sol";
import {Error} from "src/libraries/Error.sol";

/// @title CreditLineFactoryMock contract
/// @notice Contains tests for the CreditLineFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryMockTest is Test {

    address public constant OWNER = address(bytes20(keccak256("OWNER")));

    CreditLineFactoryMock public creditLineFactoryMock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        creditLineFactoryMock = new CreditLineFactoryMock();

        vm.stopPrank();
    }

    /************************************************
     *  Test `supportedKinds` function
     ***********************************************/

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        creditLineFactoryMock.supportedKinds();
    }
}

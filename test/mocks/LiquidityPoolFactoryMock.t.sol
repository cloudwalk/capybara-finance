// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {LiquidityPoolFactoryMock} from "src/mocks/LiquidityPoolFactoryMock.sol";
import {Error} from "src/libraries/Error.sol";

/// @title LiquidityPoolFactoryMockTest contract
/// @notice Contains tests for the LiquidityPoolFactoryMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryMockTest is Test {

    address public constant OWNER = address(bytes20(keccak256("OWNER")));

    LiquidityPoolFactoryMock public liquidityPoolFactoryMock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        liquidityPoolFactoryMock = new LiquidityPoolFactoryMock();

        vm.stopPrank();
    }

    /************************************************
     *  Test `supportedKinds` function
     ***********************************************/

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        liquidityPoolFactoryMock.supportedKinds();
    }
}

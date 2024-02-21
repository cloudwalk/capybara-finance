// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Error} from "src/libraries/Error.sol";
import {LiquidityPoolFactoryMock} from "src/mocks/LiquidityPoolFactoryMock.sol";

/// @title LiquidityPoolFactoryMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the LiquidityPoolFactoryMock contract
contract LiquidityPoolFactoryMockTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    /************************************************
     *  Storage variables
     ***********************************************/

    LiquidityPoolFactoryMock public mock;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        mock = new LiquidityPoolFactoryMock();
    }

    /************************************************
     *  ILiquidityPoolFactory functions
     ***********************************************/

    function test_createLiquidityPool() public {
        address LiquidityPool = address(0x0);
        address market = address(0x1);
        address lender = address(0x2);
        uint16 kind = 1;
        bytes memory data = "data";

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        LiquidityPool = mock.createLiquidityPool(market, lender, kind, data);
        assertEq(LiquidityPool, address(0x0));

        mock.mockLiquidityPoolAddress(address(0x3));
        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        LiquidityPool = mock.createLiquidityPool(market, lender, kind, data);
        assertEq(LiquidityPool, address(0x3));
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

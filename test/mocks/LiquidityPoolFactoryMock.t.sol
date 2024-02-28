// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Error } from "src/libraries/Error.sol";
import { LiquidityPoolFactoryMock } from "src/mocks/LiquidityPoolFactoryMock.sol";

/// @title LiquidityPoolFactoryMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LiquidityPoolFactoryMock` contract.
contract LiquidityPoolFactoryMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolFactoryMock public mock;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        mock = new LiquidityPoolFactoryMock();
    }

    // -------------------------------------------- //
    //  ILiquidityPoolFactory functions             //
    // -------------------------------------------- //

    function test_createLiquidityPool() public {
        address market = address(1);
        address lender = address(2);
        uint16 kind = 1;
        bytes memory data = "data";

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        assertEq(mock.createLiquidityPool(market, lender, kind, data), address(0));

        address mockedLiquidityPoolAddress = address(3);
        mock.mockCreatedLiquidityPoolAddress(mockedLiquidityPoolAddress);

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(market, lender, kind, data);
        assertEq(mock.createLiquidityPool(market, lender, kind, data), mockedLiquidityPoolAddress);
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

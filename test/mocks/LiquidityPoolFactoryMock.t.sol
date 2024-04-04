// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Error } from "src/common/libraries/Error.sol";

import { LiquidityPoolFactoryMock } from "src/mocks/LiquidityPoolFactoryMock.sol";

/// @title LiquidityPoolFactoryMockTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolFactoryMock` contract.
contract LiquidityPoolFactoryMockTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolFactoryMock private mock;

    address private constant MARKET = address(bytes20(keccak256("market")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant LIQUIDITY_POOL = address(bytes20(keccak256("liquidity_pool")));
    uint16 private constant KIND = 1;
    bytes private constant DATA = "0x123ff";

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
        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(MARKET, LENDER, KIND, DATA);
        assertEq(mock.createLiquidityPool(MARKET, LENDER, KIND, DATA), address(0));

        mock.mockCreatedLiquidityPoolAddress(LIQUIDITY_POOL);

        vm.expectEmit(true, true, true, true, address(mock));
        emit CreateLiquidityPoolCalled(MARKET, LENDER, KIND, DATA);
        assertEq(mock.createLiquidityPool(MARKET, LENDER, KIND, DATA), LIQUIDITY_POOL);
    }

    function test_supportedKinds() public {
        vm.expectRevert(Error.NotImplemented.selector);
        mock.supportedKinds();
    }
}

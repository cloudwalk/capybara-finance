// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {LiquidityPoolFactory} from "src/pools/LiquidityPoolFactory.sol";
import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";

/// @title LiquidityPoolFactoryTest contract
/// @notice Tests for the LiquidityPoolFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryTest is Test {

    /************************************************
     *  Events
     ***********************************************/

    event LiquidityPoolCreated(address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool);

    /************************************************
     *  Storage variables and constants
     ***********************************************/

    LiquidityPoolFactory public factory;

    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant EXPECTED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant EXPECTED_KIND = 1;
    uint16 public constant UNEXPECTED_KIND = 2;
    bytes public constant CREATE_DATA = "0x123ff";

    /********************************************************
     *  Setup and configuration
     *******************************************************/

    function setUp() public {
        factory = new LiquidityPoolFactory(REGISTRY);
    }

    /********************************************************
     *  Test constructor
     *******************************************************/

    function test_constructor() public {
        factory = new LiquidityPoolFactory(REGISTRY);
        assertEq(factory.owner(), REGISTRY);
    }

    function test_constructor_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        factory = new LiquidityPoolFactory(address(0));
    }

    /********************************************************
     *  Test `createLiquidityPool` function
     *******************************************************/

    function test_createLiquidityPool() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit LiquidityPoolCreated(MARKET, LENDER, EXPECTED_KIND, EXPECTED_CONTRACT_ADDRESS);
        address liquidityPool = factory.createLiquidityPool(MARKET, LENDER, EXPECTED_KIND, CREATE_DATA);

        assertEq(LiquidityPoolAccountable(liquidityPool).lender(), LENDER);
        assertEq(LiquidityPoolAccountable(liquidityPool).market(), MARKET);
        assertEq(LiquidityPoolAccountable(liquidityPool).kind(), EXPECTED_KIND);
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(LiquidityPoolFactory.UnsupportedKind.selector, UNEXPECTED_KIND));
        factory.createLiquidityPool(MARKET, LENDER, UNEXPECTED_KIND, CREATE_DATA);
    }

    function test_createLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        factory.createLiquidityPool(MARKET, LENDER, EXPECTED_KIND, CREATE_DATA);
    }

    /********************************************************
     *  Test `supportedKinds` function
     *******************************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], EXPECTED_KIND);
    }
}

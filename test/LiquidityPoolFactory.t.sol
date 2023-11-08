// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {LiquidityPoolAccountable} from "../src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "../src/pools/LiquidityPoolFactory.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title LiquidityPoolFactoryTest contract
/// @notice Tests for the LiquidityPoolFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event LiquidityPoolCreated(address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool);

    /************************************************
     *  Variables
     ***********************************************/

    LiquidityPoolFactory public factory;

    address public immutable REGISTRY = address(this);
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant CREATED_LIQUIDITY_POOL_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant LIQUIDITY_POOL_KIND_OK = 1;
    uint16 public constant LIQUIDITY_POOL_KIND_FAKE = 2;

    bytes public constant CREATE_DATA = "0x123fff";

    /********************************************************
     *  Setup and configuration
     *******************************************************/

    function setUp() public {
        factory = new LiquidityPoolFactory(REGISTRY);
    }

    /********************************************************
     *  Tests for constructor
     *******************************************************/

    function test_constructor() public {
        assertEq(factory.owner(), REGISTRY);
    }

    function test_constructor_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory = new LiquidityPoolFactory(address(0));
    }

    /********************************************************
     *  Tests for `createLiquidityPool` function
     *******************************************************/

    function test_createLiquidityPool() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit LiquidityPoolCreated(REGISTRY, LENDER, LIQUIDITY_POOL_KIND_OK, CREATED_LIQUIDITY_POOL_ADDRESS);
        address pool = factory.createLiquidityPool(MARKET, LENDER, LIQUIDITY_POOL_KIND_OK, CREATE_DATA);

        assertEq(LiquidityPoolAccountable(pool).lender(), LENDER);
        assertEq(LiquidityPoolAccountable(pool).market(), MARKET);
        assertEq(LiquidityPoolAccountable(pool).kind(), LIQUIDITY_POOL_KIND_OK);
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(LiquidityPoolFactory.UnsupportedKind.selector, LIQUIDITY_POOL_KIND_FAKE));
        factory.createLiquidityPool(MARKET, LENDER, LIQUIDITY_POOL_KIND_FAKE, CREATE_DATA);
    }

    function test_createLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        factory.createLiquidityPool(MARKET, LENDER, LIQUIDITY_POOL_KIND_OK, CREATE_DATA);
    }

    /********************************************************
     *  Tests for `supportedKinds` function
     *******************************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], LIQUIDITY_POOL_KIND_OK);
    }
}

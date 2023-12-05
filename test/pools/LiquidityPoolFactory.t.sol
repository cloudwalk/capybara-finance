// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "src/pools/LiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryTest contract
/// @notice Contains tests for the LiquidityPoolFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event CreateLiquidityPool(
        address indexed market, address indexed lender, uint16 indexed kind, address liquidityPool
    );

    /************************************************
     *  Storage variables
     ***********************************************/

    LiquidityPoolFactory public factory;

    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant EXPECTED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant KIND_1 = 1;
    uint16 public constant KIND_2 = 2;
    bytes public constant DATA = "0x123ff";

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY);
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY);
        assertEq(factory.owner(), REGISTRY);
    }

    function test_initializer_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        factory = new LiquidityPoolFactory();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory.initialize(address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(REGISTRY);
    }

    /************************************************
     *  Test `createLiquidityPool` function
     ***********************************************/

    function test_createLiquidityPool() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreateLiquidityPool(MARKET, LENDER, KIND_1, EXPECTED_CONTRACT_ADDRESS);
        address liquidityPool = factory.createLiquidityPool(MARKET, LENDER, KIND_1, DATA);

        assertEq(LiquidityPoolAccountable(liquidityPool).lender(), LENDER);
        assertEq(LiquidityPoolAccountable(liquidityPool).market(), MARKET);
        assertEq(LiquidityPoolAccountable(liquidityPool).kind(), KIND_1);
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(LiquidityPoolFactory.UnsupportedKind.selector);
        factory.createLiquidityPool(MARKET, LENDER, KIND_2, DATA);
    }

    function test_createLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        factory.createLiquidityPool(MARKET, LENDER, KIND_1, DATA);
    }

    /************************************************
     *  Test `supportedKinds` function
     ***********************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], KIND_1);
    }
}

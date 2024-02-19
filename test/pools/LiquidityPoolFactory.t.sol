// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "src/pools/LiquidityPoolFactory.sol";

import {Config} from "test/base/Config.sol";

/// @title LiquidityPoolFactoryTest contract
/// @notice Contains tests for the LiquidityPoolFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryTest is Test, Config {
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
    address public constant DEPLOYED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
        assertEq(factory.owner(), REGISTRY_1);
    }

    function test_initializer_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY_1);
        factory = new LiquidityPoolFactory();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory.initialize(address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(REGISTRY_1);
    }

    /************************************************
     *  Test `createLiquidityPool` function
     ***********************************************/

    function test_createLiquidityPool() public {
        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreateLiquidityPool(MARKET, LENDER_1, KIND_1, DEPLOYED_CONTRACT_ADDRESS);
        address liquidityPool = factory.createLiquidityPool(MARKET, LENDER_1, KIND_1, DATA);

        assertEq(LiquidityPoolAccountable(liquidityPool).lender(), LENDER_1);
        assertEq(LiquidityPoolAccountable(liquidityPool).market(), MARKET);
        assertEq(LiquidityPoolAccountable(liquidityPool).kind(), KIND_1);
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY_1);
        vm.expectRevert(LiquidityPoolFactory.UnsupportedKind.selector);
        factory.createLiquidityPool(MARKET, LENDER_1, KIND_2, DATA);
    }

    function test_createLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        factory.createLiquidityPool(MARKET, LENDER_1, KIND_1, DATA);
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

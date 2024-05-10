// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { LiquidityPoolAccountable } from "src/liquidity-pools/LiquidityPoolAccountable.sol";
import { LiquidityPoolFactory } from "src/liquidity-pools/LiquidityPoolFactory.sol";

/// @title LiquidityPoolFactoryTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolFactory` contract.
contract LiquidityPoolFactoryTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event LiquidityPoolCreated(
        address indexed market,
        address indexed lender,
        uint16 indexed kind,
        address liquidityPool
    );

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolFactory private factory;

    address private constant MARKET = address(bytes20(keccak256("market")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));
    address private constant REGISTRY_1 = address(bytes20(keccak256("registry_1")));
    address private constant REGISTRY_2 = address(bytes20(keccak256("registry_2")));
    address private constant EXPECTED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint16 private constant KIND_1 = 1;
    uint16 private constant KIND_2 = 2;
    bytes private constant DATA = "0x123ff";

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
    }

    // -------------------------------------------- //
    //  Test initializer                            //
    // -------------------------------------------- //

    function test_initializer() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
        assertEq(factory.hasRole(OWNER_ROLE, REGISTRY_1), true);
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        factory = new LiquidityPoolFactory();
        factory.initialize(REGISTRY_1);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(REGISTRY_2);
    }

    // -------------------------------------------- //
    //  Test `createLiquidityPool` function         //
    // -------------------------------------------- //

    function test_createLiquidityPool() public {
        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(factory));
        emit LiquidityPoolCreated(MARKET, LENDER, KIND_1, EXPECTED_CONTRACT_ADDRESS);
        address liquidityPool = factory.createLiquidityPool(MARKET, LENDER, KIND_1, DATA);

        assertEq(liquidityPool, EXPECTED_CONTRACT_ADDRESS);
        assertEq(LiquidityPoolAccountable(liquidityPool).lender(), LENDER);
        assertEq(LiquidityPoolAccountable(liquidityPool).market(), MARKET);
        assertEq(LiquidityPoolAccountable(liquidityPool).kind(), KIND_1);
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY_1);
        vm.expectRevert(LiquidityPoolFactory.UnsupportedKind.selector);
        factory.createLiquidityPool(MARKET, LENDER, KIND_2, DATA);
    }

    function test_createLiquidityPool_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        factory.createLiquidityPool(MARKET, LENDER, KIND_1, DATA);
    }

    // -------------------------------------------- //
    //  Test `supportedKinds` function              //
    // -------------------------------------------- //

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], KIND_1);
    }
}

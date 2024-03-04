// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { LiquidityPoolFactoryUUPS } from "src/pools/LiquidityPoolFactoryUUPS.sol";

/// @title LiquidityPoolFactoryUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LiquidityPoolFactoryUUPS` contract.
contract LiquidityPoolFactoryUUPSTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolFactoryUUPS public proxy;

    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = LiquidityPoolFactoryUUPS(address(new ERC1967Proxy(address(new LiquidityPoolFactoryUUPS()), "")));
        proxy.initialize(OWNER);
    }

    // -------------------------------------------- //
    //  Test `upgradeToAndCall` function            //
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LiquidityPoolFactoryUUPS());
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfCallerNotOwner() public {
        address newImplemetation = address(new LiquidityPoolFactoryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LiquidityPoolFactoryUUPS} from "src/pools/LiquidityPoolFactoryUUPS.sol";

import {Config} from "test/base/Config.sol";

/// @title LiquidityPoolFactoryUUPSTest contract
/// @notice Contains tests for the LiquidityPoolFactoryUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LiquidityPoolFactoryUUPSTest is Test, Config {
    /************************************************
     *  Events
     ***********************************************/

    event Upgraded(address indexed implementation);

    /************************************************
     *  Storage variables
     ***********************************************/

    LiquidityPoolFactoryUUPS public proxy;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        proxy = LiquidityPoolFactoryUUPS(address(new ERC1967Proxy(address(new LiquidityPoolFactoryUUPS()), "")));
        proxy.initialize(REGISTRY);
    }

    /************************************************
     *  Test `upgradeToAndCall` function
     ***********************************************/

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LiquidityPoolFactoryUUPS());
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfNotOwner() public {
        address newImplemetation = address(new LiquidityPoolFactoryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

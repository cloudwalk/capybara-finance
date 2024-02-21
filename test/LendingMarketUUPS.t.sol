// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LendingMarketUUPS} from "src/LendingMarketUUPS.sol";

import {Config} from "test/base/Config.sol";

/// @title LendingMarketUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the LendingMarketUUPS contract
contract LendingMarketUUPSTest is Test, Config {
    /************************************************
     *  Events
     ***********************************************/

    event Upgraded(address indexed implementation);

    /************************************************
     *  Storage variables
     ***********************************************/

    LendingMarketUUPS public proxy;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        proxy = LendingMarketUUPS(address(new ERC1967Proxy(address(new LendingMarketUUPS()), "")));
        proxy.initialize("NAME", "SYMBOL");
        proxy.transferOwnership(OWNER);
    }

    /************************************************
     *  Test `upgradeToAndCall` function
     ***********************************************/

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LendingMarketUUPS());
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfNotOwner() public {
        address newImplemetation = address(new LendingMarketUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

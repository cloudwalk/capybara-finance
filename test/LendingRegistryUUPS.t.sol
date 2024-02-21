// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {LendingRegistryUUPS} from "src/LendingRegistryUUPS.sol";

/// @title LendingRegistryUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the LendingRegistryUUPS contract
contract LendingRegistryUUPSTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LendingRegistryUUPS public proxy;

    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = LendingRegistryUUPS(address(new ERC1967Proxy(address(new LendingRegistryUUPS()), "")));
        proxy.initialize(MARKET);
        proxy.transferOwnership(OWNER);
    }

    // -------------------------------------------- //
     *  Test `upgradeToAndCall` function
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LendingRegistryUUPS());
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfNotOwner() public {
        address newImplemetation = address(new LendingRegistryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

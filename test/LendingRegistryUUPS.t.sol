// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { LendingRegistryUUPS } from "src/LendingRegistryUUPS.sol";

/// @title LendingRegistryUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LendingRegistryUUPS` contract.
contract LendingRegistryUUPSTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LendingRegistryUUPS private proxy;

    address private constant OWNER = address(bytes20(keccak256("owner")));
    address private constant MARKET = address(bytes20(keccak256("market")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = LendingRegistryUUPS(address(new ERC1967Proxy(address(new LendingRegistryUUPS()), "")));
        vm.prank(OWNER);
        proxy.initialize(MARKET);
    }

    // -------------------------------------------- //
    //  Test `upgradeToAndCall` function            //
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LendingRegistryUUPS());
        vm.prank(OWNER);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfCallerNotOwner() public {
        address newImplemetation = address(new LendingRegistryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

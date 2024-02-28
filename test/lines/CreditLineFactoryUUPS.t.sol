// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { CreditLineFactoryUUPS } from "src/lines/CreditLineFactoryUUPS.sol";

import { Config } from "test/base/Config.sol";

/// @title CreditLineFactoryUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `CreditLineFactoryUUPS` contract.
contract CreditLineFactoryUUPSTest is Test, Config {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineFactoryUUPS public proxy;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = CreditLineFactoryUUPS(address(new ERC1967Proxy(address(new CreditLineFactoryUUPS()), "")));
        proxy.initialize(REGISTRY_1);
    }

    // -------------------------------------------- //
    //  Test `upgradeToAndCall` function            //
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new CreditLineFactoryUUPS());
        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfCallerNotOwner() public {
        address newImplemetation = address(new CreditLineFactoryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

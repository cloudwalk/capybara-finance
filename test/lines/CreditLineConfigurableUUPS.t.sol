// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {CreditLineConfigurableUUPS} from "src/lines/CreditLineConfigurableUUPS.sol";

import {Config} from "test/base/Config.sol";

/// @title CreditLineConfigurableUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `CreditLineConfigurableUUPS` contract
contract CreditLineConfigurableUUPSTest is Test, Config {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    CreditLineConfigurableUUPS public proxy;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = CreditLineConfigurableUUPS(address(new ERC1967Proxy(address(new CreditLineConfigurableUUPS()), "")));
        proxy.initialize(MARKET, LENDER_1, TOKEN_1);
    }

    // -------------------------------------------- //
    //  Test `upgradeToAndCall` function            //
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new CreditLineConfigurableUUPS());
        vm.prank(LENDER_1);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfNotOwner() public {
        address newImplemetation = address(new CreditLineConfigurableUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

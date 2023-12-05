// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {CreditLineFactoryUUPS} from "src/lines/CreditLineFactoryUUPS.sol";

/// @title CreditLineFactoryUUPSTest contract
/// @notice Contains tests for the CreditLineFactoryUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryUUPSTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event Upgraded(address indexed implementation);

    /************************************************
     *  Storage variables
     ***********************************************/

    CreditLineFactoryUUPS public proxy;

    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        proxy = CreditLineFactoryUUPS(address(new ERC1967Proxy(address(new CreditLineFactoryUUPS()), "")));
        proxy.initialize(REGISTRY);
    }

    /************************************************
     *  Test `upgradeToAndCall` function
     ***********************************************/

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new CreditLineFactoryUUPS());
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfNotOwner() public {
        address newImplemetation = address(new CreditLineFactoryUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

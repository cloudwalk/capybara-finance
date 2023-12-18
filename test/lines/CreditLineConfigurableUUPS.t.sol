// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {CreditLineConfigurableUUPS} from "src/lines/CreditLineConfigurableUUPS.sol";

/// @title CreditLineConfigurableUUPSTest contract
/// @notice Contains tests for the CreditLineConfigurableUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineConfigurableUUPSTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event Upgraded(address indexed implementation);

    /************************************************
     *  Storage variables
     ***********************************************/

    CreditLineConfigurableUUPS public proxy;

    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        proxy = CreditLineConfigurableUUPS(address(new ERC1967Proxy(address(new CreditLineConfigurableUUPS()), "")));
        proxy.initialize(MARKET, LENDER, TOKEN);
    }

    /************************************************
     *  Test `upgradeToAndCall` function
     ***********************************************/

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new CreditLineConfigurableUUPS());
        vm.prank(LENDER);
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

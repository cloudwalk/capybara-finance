// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Test } from "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { LiquidityPoolAccountableUUPS } from "src/liquidity-pools/LiquidityPoolAccountableUUPS.sol";

/// @title LiquidityPoolAccountableUUPSTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Contains tests for the `LiquidityPoolAccountableUUPS` contract.
contract LiquidityPoolAccountableUUPSTest is Test {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event Upgraded(address indexed implementation);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LiquidityPoolAccountableUUPS private proxy;

    address private constant MARKET = address(bytes20(keccak256("market")));
    address private constant LENDER = address(bytes20(keccak256("lender")));
    address private constant ATTACKER = address(bytes20(keccak256("attacker")));

    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        proxy = LiquidityPoolAccountableUUPS(
            address(new ERC1967Proxy(address(new LiquidityPoolAccountableUUPS()), ""))
        );
        proxy.initialize(MARKET, LENDER);
    }

    // -------------------------------------------- //
    //  Test `upgradeToAndCall` function            //
    // -------------------------------------------- //

    function test_upgradeToAndCall() public {
        address newImplemetation = address(new LiquidityPoolAccountableUUPS());
        vm.prank(LENDER);
        vm.expectEmit(true, true, true, true, address(proxy));
        emit Upgraded(newImplemetation);
        proxy.upgradeToAndCall(newImplemetation, "");
    }

    function test_upgradeToAndCall_Revert_IfCallerNotOwner() public {
        address newImplemetation = address(new LiquidityPoolAccountableUUPS());
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                ATTACKER, OWNER_ROLE)
        );
        proxy.upgradeToAndCall(newImplemetation, "");
    }
}

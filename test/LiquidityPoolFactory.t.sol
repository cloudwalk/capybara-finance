// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {LiquidityPoolAccountable} from "../src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "../src/pools/LiquidityPoolFactory.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract LiquidityPoolFactoryTest is Test {
    event LiquidityPoolCreated(address indexed market, uint16 indexed kind, address liquidityPool);

    address public constant EXPECTED_POOL_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;
    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;

    uint16 public constant KIND = 1;

    bytes public constant data = "";

    LiquidityPoolFactory public factory;

    function setUp() public {
        factory = new LiquidityPoolFactory(address(this));
    }

    function test_constructor() public {
        assertEq(factory.owner(), address(this));
    }

    function test_createLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(factory));
        emit LiquidityPoolCreated(address(this), KIND, EXPECTED_POOL_ADDRESS);
        address pool = factory.createLiquidityPool(address(this), address(this), KIND, data);

        assertEq(LiquidityPoolAccountable(pool).lender(), address(this));
        assertEq(LiquidityPoolAccountable(pool).market(), address(this));
    }

    function test_createLiquidityPool_Revert_IfUnsupportedKind() public {
        vm.expectRevert(abi.encodeWithSelector(LiquidityPoolFactory.UnsupportedKind.selector, 0));
        factory.createLiquidityPool(address(this), address(this), 0, data);
    }

    function test_createLiquidityPool_Revert_IfCallerNotOwner() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        factory.createLiquidityPool(address(this), address(this), KIND, data);
    }
}

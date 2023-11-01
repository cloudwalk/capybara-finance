// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract CreditLineFactoryTest is Test {
    event CreditLineCreated(address indexed market, uint16 indexed kind, address creditLine);

    address public constant EXPECTED_LINE_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;
    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;

    bytes public constant data = "";

    uint16 public constant KIND = 1;

    CreditLineFactory public factory;

    function setUp() public {
        factory = new CreditLineFactory(address(this));
    }

    function test_constructor() public {
        assertEq(factory.owner(), address(this));
    }

    function test_createCreditLine() public {
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreditLineCreated(address(this), KIND, EXPECTED_LINE_ADDRESS);
        address line = factory.createCreditLine(address(this), address(this), KIND, data);

        assertEq(CreditLineConfigurable(line).lender(), address(this));
        assertEq(CreditLineConfigurable(line).market(), address(this));
    }

    function test_createCreditLine_Revert_IfUnsupportedKind() public {
        vm.expectRevert(abi.encodeWithSelector(CreditLineFactory.UnsupportedKind.selector, 0));
        factory.createCreditLine(address(this), address(this), 0, data);
    }

    function test_createCreditLine_Revert_IfCallerNotOwner() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        factory.createCreditLine(address(this), address(this), KIND, data);
    }
}

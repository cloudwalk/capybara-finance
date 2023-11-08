// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title CreditLineFactoryTest contract
/// @notice Tests for the CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event CreditLineCreated(address indexed market, address indexed lender, uint16 indexed kind, address creditLine);

    /************************************************
     *  Variables
     ***********************************************/

    CreditLineFactory public factory;

    address public immutable REGISTRY = address(this);
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant CREATED_CREDIT_LINE_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant CREDIT_LINE_KIND_OK = 1;
    uint16 public constant CREDIT_LINE_KIND_FAKE = 2;

    bytes public constant CREATE_DATA = "0x123fff";


    /********************************************************
     *  Setup and configuration
     *******************************************************/

    function setUp() public {
        factory = new CreditLineFactory(REGISTRY);
    }

    /********************************************************
     *  Tests for constructor
     *******************************************************/

    function test_constructor() public {
        assertEq(factory.owner(), REGISTRY);
    }

    function test_constructor_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory = new CreditLineFactory(address(0));
    }

    /********************************************************
     *  Tests for `createCreditLine` function
     *******************************************************/

    function test_createCreditLine() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreditLineCreated(MARKET, LENDER, CREDIT_LINE_KIND_OK, CREATED_CREDIT_LINE_ADDRESS);
        address line = factory.createCreditLine(MARKET, LENDER, CREDIT_LINE_KIND_OK, CREATE_DATA);

        assertEq(CreditLineConfigurable(line).lender(), LENDER);
        assertEq(CreditLineConfigurable(line).market(), MARKET);
        assertEq(CreditLineConfigurable(line).kind(), CREDIT_LINE_KIND_OK);
    }

    function test_createCreditLine_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(CreditLineFactory.UnsupportedKind.selector, CREDIT_LINE_KIND_FAKE));
        factory.createCreditLine(MARKET, LENDER, CREDIT_LINE_KIND_FAKE, CREATE_DATA);
    }

    function test_createCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        factory.createCreditLine(MARKET, LENDER, CREDIT_LINE_KIND_OK, CREATE_DATA);
    }

    /********************************************************
     *  Tests for `supportedKinds` function
     *******************************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], CREDIT_LINE_KIND_OK);
    }
}

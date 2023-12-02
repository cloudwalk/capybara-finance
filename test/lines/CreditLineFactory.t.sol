// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";

/// @title CreditLineFactoryTest contract
/// @notice Contains tests for the CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryTest is Test {

    /************************************************
     *  Events
     ***********************************************/

    event CreditLineCreated(address indexed market, address indexed lender, uint16 indexed kind, address creditLine);

    /************************************************
     *  Storage variables and constants
     ***********************************************/

    CreditLineFactory public factory;

    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
        address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant EXPECTED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant EXPECTED_KIND = 1;
    uint16 public constant UNEXPECTED_KIND = 2;
    bytes public constant CREATE_DATA = "0x123ff";

    /********************************************************
     *  Setup and configuration
     *******************************************************/

    function setUp() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY);
    }

    /********************************************************
     *  Test constructor
     *******************************************************/

    function test_constructor() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY);
        assertEq(factory.owner(), REGISTRY);
    }

    function test_constructor_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        factory = new CreditLineFactory();
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        factory.initialize(address(0));
    }

    /********************************************************
     *  Test `createCreditLine` function
     *******************************************************/

    function test_createCreditLine() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreditLineCreated(MARKET, LENDER, EXPECTED_KIND, EXPECTED_CONTRACT_ADDRESS);
        address creditLine = factory.createCreditLine(MARKET, LENDER, EXPECTED_KIND, CREATE_DATA);

        assertEq(CreditLineConfigurable(creditLine).lender(), LENDER);
        assertEq(CreditLineConfigurable(creditLine).market(), MARKET);
        assertEq(CreditLineConfigurable(creditLine).kind(), EXPECTED_KIND);
    }

    function test_createCreditLine_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(abi.encodeWithSelector(CreditLineFactory.UnsupportedKind.selector, UNEXPECTED_KIND));
        factory.createCreditLine(MARKET, LENDER, UNEXPECTED_KIND, CREATE_DATA);
    }

    function test_createCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER)
        );
        factory.createCreditLine(MARKET, LENDER, EXPECTED_KIND, CREATE_DATA);
    }

    /********************************************************
     *  Test `supportedKinds` function
     *******************************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], EXPECTED_KIND);
    }
}

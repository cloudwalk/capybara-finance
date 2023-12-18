// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";

/// @title CreditLineFactoryTest contract
/// @notice Contains tests for the CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryTest is Test {
    /************************************************
     *  Events
     ***********************************************/

    event CreateCreditLine(
        address indexed market, address indexed lender, address indexed token, uint16 kind, address creditLine
    );

    /************************************************
     *  Storage variables
     ***********************************************/

    CreditLineFactory public factory;

    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant MARKET = address(bytes20(keccak256("market")));
    address public constant LENDER = address(bytes20(keccak256("lender")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant EXPECTED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    uint16 public constant KIND_1 = 1;
    uint16 public constant KIND_2 = 2;
    bytes public constant DATA = "0x123ff";

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY);
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY);
        assertEq(factory.owner(), REGISTRY);
    }

    function test_initializer_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY);
        factory = new CreditLineFactory();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory.initialize(address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(REGISTRY);
    }

    /************************************************
     *  Test `createCreditLine` function
     ***********************************************/

    function test_createCreditLine() public {
        vm.prank(REGISTRY);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreateCreditLine(MARKET, LENDER, TOKEN, KIND_1, EXPECTED_CONTRACT_ADDRESS);
        address creditLine = factory.createCreditLine(MARKET, LENDER, TOKEN, KIND_1, DATA);

        assertEq(CreditLineConfigurable(creditLine).lender(), LENDER);
        assertEq(CreditLineConfigurable(creditLine).market(), MARKET);
        assertEq(CreditLineConfigurable(creditLine).token(), TOKEN);
        assertEq(CreditLineConfigurable(creditLine).kind(), KIND_1);
    }

    function test_createCreditLine_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY);
        vm.expectRevert(CreditLineFactory.UnsupportedKind.selector);
        factory.createCreditLine(MARKET, LENDER, TOKEN, KIND_2, DATA);
    }

    function test_createCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        factory.createCreditLine(MARKET, LENDER, TOKEN, KIND_1, DATA);
    }

    /************************************************
     *  Test `supportedKinds` function
     ***********************************************/

    function test_supportedKinds() public {
        uint16[] memory kinds = factory.supportedKinds();
        assertEq(kinds.length, 1);
        assertEq(kinds[0], KIND_1);
    }
}

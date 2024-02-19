// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";

import {Config} from "test/base/Config.sol";

/// @title CreditLineFactoryTest contract
/// @notice Contains tests for the CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactoryTest is Test, Config {
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
    address public constant DEPLOYED_CONTRACT_ADDRESS = 0x104fBc016F4bb334D775a19E8A6510109AC63E00;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY_1);
    }

    /************************************************
     *  Test initializer
     ***********************************************/

    function test_initializer() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY_1);
        assertEq(factory.owner(), REGISTRY_1);
    }

    function test_initializer_Revert_IfRegistryIsZeroAddress() public {
        vm.prank(REGISTRY_1);
        factory = new CreditLineFactory();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0)));
        factory.initialize(address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        factory = new CreditLineFactory();
        factory.initialize(REGISTRY_1);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(REGISTRY_1);
    }

    /************************************************
     *  Test `createCreditLine` function
     ***********************************************/

    function test_createCreditLine() public {
        vm.prank(REGISTRY_1);
        vm.expectEmit(true, true, true, true, address(factory));
        emit CreateCreditLine(MARKET, LENDER_1, TOKEN_1, KIND_1, DEPLOYED_CONTRACT_ADDRESS);
        address creditLine = factory.createCreditLine(MARKET, LENDER_1, TOKEN_1, KIND_1, DATA);

        assertEq(CreditLineConfigurable(creditLine).lender(), LENDER_1);
        assertEq(CreditLineConfigurable(creditLine).market(), MARKET);
        assertEq(CreditLineConfigurable(creditLine).token(), TOKEN_1);
        assertEq(CreditLineConfigurable(creditLine).kind(), KIND_1);
    }

    function test_createCreditLine_Revert_IfUnsupportedKind() public {
        vm.prank(REGISTRY_1);
        vm.expectRevert(CreditLineFactory.UnsupportedKind.selector);
        factory.createCreditLine(MARKET, LENDER_1, TOKEN_1, KIND_2, DATA);
    }

    function test_createCreditLine_Revert_IfCallerNotRegistry() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        factory.createCreditLine(MARKET, LENDER_1, TOKEN_1, KIND_1, DATA);
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

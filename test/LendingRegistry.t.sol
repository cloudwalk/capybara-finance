// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Error } from "src/libraries/Error.sol";
import { LendingRegistry } from "src/LendingRegistry.sol";
import { LendingMarketMock } from "src/mocks/LendingMarketMock.sol";
import { CreditLineFactoryMock } from "src/mocks/CreditLineFactoryMock.sol";
import { LiquidityPoolFactoryMock } from "src/mocks/LiquidityPoolFactoryMock.sol";

import { Config } from "test/base/Config.sol";

/// @title LendingRegistryTest contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Contains tests for the `LendingRegistry` contract
contract LendingRegistryTest is Test, Config {
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    event SetCreditLineFactory(address newFactory, address oldFactory);
    event SetLiquidityPoolFactory(address newFactory, address oldFactory);

    event CreateCreditLine(address indexed lender, address creditLine);
    event CreateLiquidityPool(address indexed lender, address liquidityPool);

    event RegisterCreditLineCalled(address indexed lender, address indexed creditLine);
    event RegisterLiquidityPoolCalled(address indexed lender, address indexed liquidityPool);

    event CreateCreditLineCalled(
        address indexed market, address indexed lender, address indexed token, uint16 kind, bytes data
    );
    event CreateLiquidityPoolCalled(address indexed market, address indexed lender, uint16 indexed kind, bytes data);

    // -------------------------------------------- //
    //  Storage variables                           //
    // -------------------------------------------- //

    LendingRegistry public registry;
    LendingMarketMock public lendingMarket;
    CreditLineFactoryMock public creditLineFactory;
    LiquidityPoolFactoryMock public liquidityPoolFactory;

    // -------------------------------------------- //
    //  Setup and configuration                     //
    // -------------------------------------------- //

    function setUp() public {
        lendingMarket = new LendingMarketMock();
        creditLineFactory = new CreditLineFactoryMock();
        liquidityPoolFactory = new LiquidityPoolFactoryMock();

        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));

        registry.transferOwnership(OWNER);
    }

    // -------------------------------------------- //
    //  Test `initialize` function                  //
    // -------------------------------------------- //

    function test_initialize() public {
        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        assertEq(registry.market(), address(lendingMarket));
    }

    function test_initialize_Revert_IfMarketIsZeroAddress() public {
        registry = new LendingRegistry();
        vm.expectRevert(Error.ZeroAddress.selector);
        registry.initialize(address(0));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(address(lendingMarket));
    }

    // -------------------------------------------- //
    //  Test `pause` function                       //
    // -------------------------------------------- //

    function test_pause() public {
        assertEq(registry.paused(), false);
        vm.prank(OWNER);
        registry.pause();
        assertEq(registry.paused(), true);
    }

    function test_pause_Revert_IfContractIsPaused() public {
        vm.startPrank(OWNER);
        registry.pause();
        assertEq(registry.paused(), true);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        registry.pause();
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        registry.pause();
    }

    // -------------------------------------------- //
    //  Test `unpause` function                     //
    // -------------------------------------------- //

    function test_unpause() public {
        vm.startPrank(OWNER);
        assertEq(registry.paused(), false);
        registry.pause();
        assertEq(registry.paused(), true);
        registry.unpause();
        assertEq(registry.paused(), false);
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(registry.paused(), false);
        vm.prank(OWNER);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        registry.unpause();
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        vm.prank(OWNER);
        registry.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        registry.unpause();
    }

    // -------------------------------------------- //
    //  Test `setCreditLineFactory` function        //
    // -------------------------------------------- //

    function test_setCreditLineFactory() public {
        assertEq(registry.creditLineFactory(), address(0));

        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetCreditLineFactory(CREDIT_LINE_FACTORY_1, address(0));
        registry.setCreditLineFactory(CREDIT_LINE_FACTORY_1);
        assertEq(registry.creditLineFactory(), CREDIT_LINE_FACTORY_1);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetCreditLineFactory(CREDIT_LINE_FACTORY_2, CREDIT_LINE_FACTORY_1);
        registry.setCreditLineFactory(CREDIT_LINE_FACTORY_2);
        assertEq(registry.creditLineFactory(), CREDIT_LINE_FACTORY_2);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetCreditLineFactory(address(0), CREDIT_LINE_FACTORY_2);
        registry.setCreditLineFactory(address(0));
        assertEq(registry.creditLineFactory(), address(0));
    }

    function test_setCreditLineFactory_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        registry.setCreditLineFactory(CREDIT_LINE_FACTORY_1);
    }

    function test_setCreditLineFactory_Revert_IfAlreadyConfigured() public {
        vm.startPrank(OWNER);
        registry.setCreditLineFactory(CREDIT_LINE_FACTORY_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        registry.setCreditLineFactory(CREDIT_LINE_FACTORY_1);
    }

    // -------------------------------------------- //
    //  Test `setLiquidityPoolFactory` function     //
    // -------------------------------------------- //

    function test_setLiquidityPoolFactory() public {
        assertEq(registry.liquidityPoolFactory(), address(0));

        vm.startPrank(OWNER);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_1, address(0));
        registry.setLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_1);
        assertEq(registry.liquidityPoolFactory(), LIQUIDITY_POOL_FACTORY_1);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_2, LIQUIDITY_POOL_FACTORY_1);
        registry.setLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_2);
        assertEq(registry.liquidityPoolFactory(), LIQUIDITY_POOL_FACTORY_2);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SetLiquidityPoolFactory(address(0), LIQUIDITY_POOL_FACTORY_2);
        registry.setLiquidityPoolFactory(address(0));
        assertEq(registry.liquidityPoolFactory(), address(0));
    }

    function test_setLiquidityPoolFactory_Revert_IfCallerNotOwner() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, ATTACKER));
        registry.setLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_1);
    }

    function test_setLiquidityPoolFactory_Revert_IfAlreadyConfigured() public {
        vm.startPrank(OWNER);
        registry.setLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_1);
        vm.expectRevert(Error.AlreadyConfigured.selector);
        registry.setLiquidityPoolFactory(LIQUIDITY_POOL_FACTORY_1);
    }

    // -------------------------------------------- //
    //  Test `createCreditLine` function            //
    // -------------------------------------------- //

    function test_createCreditLine() public {
        vm.startPrank(OWNER);

        creditLineFactory.mockCreatedCreditLineAddress(EXPECTED_CONTRACT_ADDRESS);
        registry.setCreditLineFactory(address(creditLineFactory));

        vm.expectEmit(true, true, true, true, address(creditLineFactory));
        emit CreateCreditLineCalled(address(lendingMarket), OWNER, TOKEN_1, KIND_1, "0x");

        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterCreditLineCalled(OWNER, EXPECTED_CONTRACT_ADDRESS);

        registry.createCreditLine(KIND_1, TOKEN_1);
    }

    function test_createCreditLine_Revert_IfFactoryNotConfigured() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingRegistry.CreditLineFactoryNotConfigured.selector);
        registry.createCreditLine(KIND_1, TOKEN_1);
    }

    // -------------------------------------------- //
    //  Test `createLiquidityPool` function         //
    // -------------------------------------------- //

    function test_createLiquidityPool() public {
        vm.startPrank(OWNER);

        liquidityPoolFactory.mockCreatedLiquidityPoolAddress(EXPECTED_CONTRACT_ADDRESS);
        registry.setLiquidityPoolFactory(address(liquidityPoolFactory));

        vm.expectEmit(true, true, true, true, address(liquidityPoolFactory));
        emit CreateLiquidityPoolCalled(address(lendingMarket), OWNER, KIND_1, "0x");

        vm.expectEmit(true, true, true, true, address(lendingMarket));
        emit RegisterLiquidityPoolCalled(OWNER, EXPECTED_CONTRACT_ADDRESS);

        registry.createLiquidityPool(KIND_1);
    }

    function test_createLiquidityPool_Revert_IfFactoryNotConfigured() public {
        vm.prank(OWNER);
        vm.expectRevert(LendingRegistry.LiquidityPoolFactoryNotConfigured.selector);
        registry.createLiquidityPool(KIND_1);
    }
}

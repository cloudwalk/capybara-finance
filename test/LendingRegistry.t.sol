// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {LiquidityPoolAccountable} from "../src/pools/LiquidityPoolAccountable.sol";
import {CreditLineConfigurable} from "../src/lines/CreditLineConfigurable.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Loan} from "src/libraries/Loan.sol";
import {CapybaraNFT} from "../src/CapybaraNFT.sol";
import {LendingRegistry} from "../src/LendingRegistry.sol";
import {Token} from "./mocks/Token.sol";
import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {LiquidityPoolFactory} from "../src/pools/LiquidityPoolFactory.sol";
import {LendingRegistry} from "../src/LendingRegistry.sol";
import {LendingMarket} from "../src/LendingMarket.sol";

import {Error} from "../src/libraries/Error.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract LendingRegistryTest is Test {
    event CreditLineRegistered(address indexed lender, address indexed creditLine);
    event LiquidityPoolRegistered(address indexed lender, address indexed liquidityPool);
    event CreditLineCreated(address indexed lender, address creditLine);
    event LiquidityPoolCreated(address indexed lender, address liquidityPool);
    event CreditLineFactorySet(address newFactory, address oldFactory);
    event LiquidityPoolFactorySet(address newFactory, address oldFactory);

    string public constant TOKEN_NAME = "CapybaraFinance";
    string public constant TOKEN_SYMBOL = "CAPY";

    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;
    address public constant EXPECTED_CONTRACT_ADDRESS = 0xDDA0a8D7486686d36449792617565E6C474fBa3f;

    uint16 public constant KIND = 1;
    uint256 public constant MINT_AMOUNT = 1000000;

    LiquidityPoolAccountable public pool;
    CreditLineConfigurable public line;
    Token public token;
    LendingMarket public marketLogic;
    LendingMarket public market;
    CapybaraNFT public nftLogic;
    CapybaraNFT public nft;
    LendingRegistry public registryLogic;
    LendingRegistry public registry;

    function setUp() public {
        token = new Token(MINT_AMOUNT);
        nftLogic = new CapybaraNFT();
        marketLogic = new LendingMarket();
        registryLogic = new LendingRegistry();

        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftLogic), "");
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");

        market = LendingMarket(address(marketProxy));

        nft = CapybaraNFT(address(nftProxy));
        nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));

        market.initialize(address(nft));

        registry = LendingRegistry(address(registryProxy));
        registry.initialize(address(market));

        market.setRegistry(address(registry));

        pool = new LiquidityPoolAccountable(address(market), address(this));
        line = new CreditLineConfigurable(address(market), address(this));

        token.approve(address(pool), type(uint256).max);
        token.approve(address(market), type(uint256).max);

        vm.prank(address(pool));
        token.approve(address(market), type(uint256).max);
    }

    function test_initialize() public {
        nftLogic = new CapybaraNFT();
        marketLogic = new LendingMarket();
        registryLogic = new LendingRegistry();

        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftLogic), "");
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");

        market = LendingMarket(address(marketProxy));

        nft = CapybaraNFT(address(nftProxy));
        nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));

        market.initialize(address(nft));

        registry = LendingRegistry(address(registryProxy));
        registry.initialize(address(market));

        pool = new LiquidityPoolAccountable(address(market), address(this));
        line = new CreditLineConfigurable(address(market), address(this));

        assertEq(registry.owner(), address(this));
        assertEq(registry.market(), address(market));
    }

    function test_initialize_Revert_IfCalledSecondTime() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(address(this));
    }

    function test_pause() public {
        assertEq(registry.paused(), false);
        registry.pause();
        assertEq(registry.paused(), true);
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        registry.pause();
    }

    function test_pause_Revert_IfContractPaused() public {
        registry.pause();
        assertEq(registry.paused(), true);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        registry.pause();
    }

    function test_unpause() public {
        assertEq(registry.paused(), false);
        registry.pause();
        assertEq(registry.paused(), true);
        registry.unpause();
        assertEq(registry.paused(), false);
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        registry.pause();
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        registry.unpause();
    }

    function test_unpause_Revert_IfContractNotPaused() public {
        assertEq(registry.paused(), false);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        registry.unpause();
    }

    function test_setCreditLineFactory() public {
        vm.expectEmit(true, true, true, true, address(registry));
        emit CreditLineFactorySet(address(this), address(0));
        registry.setCreditLineFactory(address(this));

        assertEq(registry.creditLineFactory(), address(this));
    }

    function test_setCreditLineFactory_Revert_IfCallerNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        registry.setCreditLineFactory(address(this));
    }

    function test_setCreditLineFactory_Revert_IfAlreadyConfigured() public {
        registry.setCreditLineFactory(address(this));
        vm.expectRevert(Error.AlreadyConfigured.selector);
        registry.setCreditLineFactory(address(this));
    }

    function test_setLiquidityPoolFactory() public {
        vm.expectEmit(true, true, true, true, address(registry));
        emit LiquidityPoolFactorySet(address(this), address(0));
        registry.setLiquidityPoolFactory(address(this));

        assertEq(registry.liquidityPoolFactory(), address(this));
    }

    function test_setLiquidityPoolFactory_Revert_IfCallerNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        registry.setLiquidityPoolFactory(address(this));
    }

    function test_setLiquidityPoolFactory_Revert_IfAlreadyConfigured() public {
        registry.setLiquidityPoolFactory(address(this));

        vm.expectRevert(Error.AlreadyConfigured.selector);
        registry.setLiquidityPoolFactory(address(this));
    }

    function test_createCreditLine() public {
        CreditLineFactory factory = new CreditLineFactory(address(registry));
        registry.setCreditLineFactory(address(factory));

        vm.expectEmit(true, true, true, true, address(registry));
        emit CreditLineCreated(address(this), EXPECTED_CONTRACT_ADDRESS);
        registry.createCreditLine(KIND);

        assertEq(CreditLineConfigurable(EXPECTED_CONTRACT_ADDRESS).market(), address(market));
        assertEq(CreditLineConfigurable(EXPECTED_CONTRACT_ADDRESS).lender(), address(this));
    }

    function test_createCreditLine_Revert_IfFactoryNotConfigured() public {
        vm.expectRevert(LendingRegistry.CreditLineFactoryNotSet.selector);
        registry.createCreditLine(KIND);
    }

    function test_createLiquidityPool() public {
        LiquidityPoolFactory factory = new LiquidityPoolFactory(address(registry));
        registry.setLiquidityPoolFactory(address(factory));

        vm.expectEmit(true, true, true, true, address(registry));
        emit LiquidityPoolCreated(address(this), EXPECTED_CONTRACT_ADDRESS);
        registry.createLiquidityPool(KIND);
    }

    function test_createLiquidityPool_Revert_IfFactoryNotConfigured() public {
        vm.expectRevert(LendingRegistry.LiquidityPoolFactoryNotSet.selector);
        registry.createLiquidityPool(KIND);
    }

    function test_registerCreditLine() public {
        vm.expectEmit(true, true, true, true, address(market));
        emit CreditLineRegistered(address(this), address(line));
        registry.registerCreditLine(address(this), address(line));

        assertEq(market.getLender(address(line)), address(this));
    }

    function test_registerCreditLine_Revert_IfLenderAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerCreditLine(address(0), address(line));
    }

    function test_registerCreditLine_Revert_IfCreditLineAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerCreditLine(address(this), address(0));
    }

    function test_registerCreditLine_Revert_IfCreditLineIsAlreadyRegistered() public {
        registry.registerCreditLine(address(this), address(line));
        vm.expectRevert(LendingMarket.CreditLineAlreadyRegistered.selector);
        registry.registerCreditLine(address(this), address(line));
    }

    function test_registerCreditLine_Revert_IfCallerNotOwner() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        registry.registerCreditLine(address(this), address(line));
    }

    function test_registerLiquidityPool() public {
        vm.expectEmit(true, true, true, true, address(market));
        emit LiquidityPoolRegistered(address(this), address(pool));
        registry.registerLiquidityPool(address(this), address(pool));

        assertEq(market.getLiquidityPool(address(this)), address(pool));
    }

    function test_registerLiquidityPool_Revert_lfLenderAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerLiquidityPool(address(0), address(pool));
    }

    function test_registerLiquidityPool_Revert_IfPoolAddressZero() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        registry.registerLiquidityPool(address(this), address(0));
    }

    function test_registerLiquidityPool_Revert_IfPoolIsAlreadyRegistered() public {
        registry.registerLiquidityPool(address(this), address(pool));
        vm.expectRevert(LendingMarket.LiquidityPoolAlreadyRegistered.selector);
        registry.registerLiquidityPool(address(this), address(pool));
    }

    function test_registerLiquidityPool_Revert_IfCallerNotOwner() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        registry.registerLiquidityPool(address(this), address(pool));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Error} from "src/libraries/Error.sol";
import {Loan} from "src/libraries/Loan.sol";
import {Interest} from "src/libraries/Interest.sol";

import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";

import {LendingMarket} from "src/LendingMarket.sol";
import {LendingRegistry} from "src/LendingRegistry.sol";

import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";
import {CreditLineFactory} from "src/lines/CreditLineFactory.sol";
import {LiquidityPoolAccountable} from "src/pools/LiquidityPoolAccountable.sol";
import {LiquidityPoolFactory} from "src/pools/LiquidityPoolFactory.sol";

import {Config} from "./base/Config.sol";

/// @title LendingMarketTest contract
/// @notice Contains complex tests for the LendingMarket contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingMarketComplexTest is Test, Config {
    ERC20Mock public token;
    LendingRegistry public registry;
    LendingMarket public lendingMarket;

    LiquidityPoolAccountable public liquidityPool;

    address public borrower;
    uint256 public borrowerBlockTimestamp;
    CreditLineConfigurable.CreditLineConfig public creditLineConfig;
    CreditLineConfigurable.BorrowerConfig public borrowerConfig;

    string public constant NAME = "TEST";
    string public constant SYMBOL = "TST";

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant TOKEN = address(bytes20(keccak256("token")));
    address public constant OWNER = address(bytes20(keccak256("owner")));
    address public constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address public constant LENDER_2 = address(bytes20(keccak256("lender_2")));
    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant REGISTRY_1 = address(bytes20(keccak256("registry_1")));
    address public constant CREDIT_LINE_1 = address(bytes20(keccak256("credit_line_1")));
    address public constant CREDIT_LINE_2 = address(bytes20(keccak256("credit_line_2")));
    address public constant LIQUIDITY_POOL_1 = address(bytes20(keccak256("liquidity_pool_1")));
    address public constant LIQUIDITY_POOL_2 = address(bytes20(keccak256("liquidity_pool_2")));

    uint256 public constant NEW_BORROWER_DURATION_IN_PERIODS = 200;
    uint256 public constant NEW_MORATORIUM_PERIODS = 20;
    uint256 public constant NEW_INTEREST_RATE_PRIMARY = 450;
    uint256 public constant NEW_INTEREST_RATE_SECONDARY = 550;

    uint256 public constant TOKEN_AMOUNT = 1000000000;
    uint256 public constant CREDITLINE_DEPOSIT_AMOUNT = 1000000;
    uint256 public constant BORROWER_LEND_AMOUNT = 600;
    uint256 public constant BORROWER_REPAY_AMOUNT = 200;
    uint256 public constant BORROWER_REPAY_BIG_AMOUNT = 100000;

    uint256 public constant BASE_BLOCKTIMESTAMP = 1641070800;
    uint256 public constant INCREASE_BLOCKTIMESTAMP = 1000;
    uint256 public constant ZERO_VALUE = 0;

    /************************************************
     *  Setup and configuration
     ***********************************************/

    function setUp() public {
        vm.startPrank(OWNER);
        //Create LendingMarket
        lendingMarket = new LendingMarket();
        lendingMarket.initialize(NAME, SYMBOL);
        lendingMarket.transferOwnership(OWNER);
        //Create Registry and set it to LendingMarket
        configureRegistry();
        vm.stopPrank();
    }

    function configureRegistry() public {
        registry = new LendingRegistry();
        registry.initialize(address(lendingMarket));
        registry.transferOwnership(OWNER);
        lendingMarket.setRegistry(address(registry));
    }

    function test_Complex() public {
        assertEq(lendingMarket.name(), NAME);
    }
}
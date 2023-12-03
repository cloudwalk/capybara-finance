// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {ICreditLine} from "./interfaces/core/ICreditLine.sol";
import {ILiquidityPool} from "./interfaces/core/ILiquidityPool.sol";
import {ICreditLineFactory} from "./interfaces/ICreditLineFactory.sol";
import {ILiquidityPoolFactory} from "./interfaces/ILiquidityPoolFactory.sol";
import {ILendingRegistry} from "./interfaces/core/ILendingRegistry.sol";
import {ILendingMarket} from "./interfaces/core/ILendingMarket.sol";

import {Error} from "./libraries/Error.sol";
import {LendingRegistryStorage} from "./LendingRegistryStorage.sol";

/// @title LendingRegistry contract
/// @notice Implementation of the lending registry contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract LendingRegistry is
    LendingRegistryStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ILendingRegistry
{
    /************************************************
     *  Events
     ***********************************************/

    /// @notice Emitted when the credit line factory is set
    /// @param newFactory The address of the new credit line factory
    /// @param oldFactory The address of the old credit line factory
    event CreditLineFactorySet(address newFactory, address oldFactory);

    /// @notice Emitted when the liquidity pool factory is set
    /// @param newFactory The address of the new liquidity pool factory
    /// @param oldFactory The address of the old liquidity pool factory
    event LiquidityPoolFactorySet(address newFactory, address oldFactory);

    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the credit line factory is not set
    error CreditLineFactoryNotSet();

    /// @notice Thrown when the liquidity pool factory is not set
    error LiquidityPoolFactoryNotSet();

    /************************************************
     *  Initializers
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    function initialize(address market_) external initializer {
        __LendingRegistry_init(market_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    function __LendingRegistry_init(address market_) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __LendingRegistry_init_unchained(market_);
    }

    /// @notice Unchained internal initializer of the upgradable contract
    /// @param market_ The address of the associated lending market
    function __LendingRegistry_init_unchained(address market_) internal onlyInitializing {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
    }

    /************************************************
     *  Owner functions
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Registers a credit line in the lending market
    /// @param lender The address of the credit line lender to register
    /// @param creditLine The address of the credit line contract to register
    function registerCreditLine(address lender, address creditLine) external onlyOwner {
        ILendingMarket(_market).registerCreditLine(lender, creditLine);
    }

    /// @notice Registers a liquidity pool in the lending market
    /// @param lender The address of the liquidity pool lender to register
    /// @param liquidityPool The address of the liquidity pool contract to register
    function registerLiquidityPool(address lender, address liquidityPool) external onlyOwner {
        ILendingMarket(_market).registerLiquidityPool(lender, liquidityPool);
    }

    /// @notice Sets the credit line factory contract
    /// @param newFactory The address of the new credit line factory
    function setCreditLineFactory(address newFactory) external onlyOwner {
        if (_creditLineFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit CreditLineFactorySet(newFactory, _creditLineFactory);

        _creditLineFactory = newFactory;
    }

    /// @notice Sets the liquidity pool factory contract
    /// @param newFactory The address of the new liquidity pool factory
    function setLiquidityPoolFactory(address newFactory) external onlyOwner {
        if (_liquidityPoolFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit LiquidityPoolFactorySet(newFactory, _liquidityPoolFactory);

        _liquidityPoolFactory = newFactory;
    }

    /************************************************
     *  Public functions
     ***********************************************/

    /// @inheritdoc ILendingRegistry
    function createCreditLine(uint16 kind) external whenNotPaused {
        if (_creditLineFactory == address(0)) {
            revert CreditLineFactoryNotSet();
        }

        address creditLine = ICreditLineFactory(_creditLineFactory).createCreditLine(_market, msg.sender, kind, "0x");

        emit CreditLineCreated(msg.sender, creditLine);

        ILendingMarket(_market).registerCreditLine(msg.sender, creditLine);
    }

    /// @inheritdoc ILendingRegistry
    function createLiquidityPool(uint16 kind) external whenNotPaused {
        if (_liquidityPoolFactory == address(0)) {
            revert LiquidityPoolFactoryNotSet();
        }

        address liquidityPool =
            ILiquidityPoolFactory(_liquidityPoolFactory).createLiquidityPool(_market, msg.sender, kind, "0x");

        emit LiquidityPoolCreated(msg.sender, liquidityPool);

        ILendingMarket(_market).registerLiquidityPool(msg.sender, liquidityPool);
    }

    /************************************************
     *  view functions
     ***********************************************/

    /// @inheritdoc ILendingRegistry
    function creditLineFactory() external view returns (address) {
        return _creditLineFactory;
    }

    /// @inheritdoc ILendingRegistry
    function liquidityPoolFactory() external view returns (address) {
        return _liquidityPoolFactory;
    }

    /// @inheritdoc ILendingRegistry
    function market() external view returns (address) {
        return _market;
    }
}

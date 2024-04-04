// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Error } from "src/common/libraries/Error.sol";

import { ILendingMarket } from "src/common/interfaces/core/ILendingMarket.sol";
import { ILendingRegistry } from "src/common/interfaces/core/ILendingRegistry.sol";
import { ILiquidityPoolFactory } from "src/common/interfaces/ILiquidityPoolFactory.sol";
import { ICreditLineFactory } from "src/common/interfaces/ICreditLineFactory.sol";

import { LendingRegistryStorage } from "./LendingRegistryStorage.sol";

/// @title LendingRegistry contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the lending registry contract.
contract LendingRegistry is
    LendingRegistryStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ILendingRegistry
{
    // -------------------------------------------- //
    //  Events                                      //
    // -------------------------------------------- //

    /// @dev Emitted when the credit line factory is changed.
    /// @param newFactory The address of the new credit line factory.
    /// @param oldFactory The address of the old credit line factory.
    event CreditLineFactoryChanged(address newFactory, address oldFactory);

    /// @dev Emitted when the liquidity pool factory is changed.
    /// @param newFactory The address of the new liquidity pool factory.
    /// @param oldFactory The address of the old liquidity pool factory.
    event LiquidityPoolFactoryChanged(address newFactory, address oldFactory);

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @dev Thrown when the credit line factory is not configured.
    error CreditLineFactoryNotConfigured();

    /// @dev Thrown when the liquidity pool factory is not configured.
    error LiquidityPoolFactoryNotConfigured();

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @dev Initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    function initialize(address market_) external initializer {
        __LendingRegistry_init(market_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    function __LendingRegistry_init(address market_) internal onlyInitializing {
        __Ownable_init_unchained(msg.sender);
        __Pausable_init_unchained();
        __LendingRegistry_init_unchained(market_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    /// @param market_ The address of the lending market.
    function __LendingRegistry_init_unchained(address market_) internal onlyInitializing {
        if (market_ == address(0)) {
            revert Error.ZeroAddress();
        }

        _market = market_;
    }

    // -------------------------------------------- //
    //  Owner functions                             //
    // -------------------------------------------- //

    /// @dev Pauses the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev Sets the credit line factory.
    /// @param newFactory The address of the new credit line factory.
    function setCreditLineFactory(address newFactory) external onlyOwner {
        if (_creditLineFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit CreditLineFactoryChanged(newFactory, _creditLineFactory);

        _creditLineFactory = newFactory;
    }

    /// @dev Sets the liquidity pool factory.
    /// @param newFactory The address of the new liquidity pool factory.
    function setLiquidityPoolFactory(address newFactory) external onlyOwner {
        if (_liquidityPoolFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit LiquidityPoolFactoryChanged(newFactory, _liquidityPoolFactory);

        _liquidityPoolFactory = newFactory;
    }

    // -------------------------------------------- //
    //  Public functions                            //
    // -------------------------------------------- //

    /// @inheritdoc ILendingRegistry
    function createCreditLine(uint16 kind, address token) external whenNotPaused {
        if (_creditLineFactory == address(0)) {
            revert CreditLineFactoryNotConfigured();
        }

        address creditLine = ICreditLineFactory(_creditLineFactory).createCreditLine(
            _market,
            msg.sender,
            token,
            kind,
            "0x" // data
        );

        ILendingMarket(_market).registerCreditLine(msg.sender, creditLine);
    }

    /// @inheritdoc ILendingRegistry
    function createLiquidityPool(uint16 kind) external whenNotPaused {
        if (_liquidityPoolFactory == address(0)) {
            revert LiquidityPoolFactoryNotConfigured();
        }

        address liquidityPool = ILiquidityPoolFactory(_liquidityPoolFactory).createLiquidityPool(
            _market,
            msg.sender,
            kind,
            "0x" // data
        );

        ILendingMarket(_market).registerLiquidityPool(msg.sender, liquidityPool);
    }

    // -------------------------------------------- //
    //  View functions                              //
    // -------------------------------------------- //

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

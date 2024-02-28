// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { Error } from "./libraries/Error.sol";

import { ILendingMarket } from "./interfaces/core/ILendingMarket.sol";
import { ILendingRegistry } from "./interfaces/core/ILendingRegistry.sol";
import { ILiquidityPoolFactory } from "./interfaces/ILiquidityPoolFactory.sol";
import { ICreditLineFactory } from "./interfaces/ICreditLineFactory.sol";

import { LendingRegistryStorage } from "./LendingRegistryStorage.sol";

/// @title LendingRegistry contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Implementation of the lending registry contract.
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

    /// @notice Emitted when the credit line factory is set.
    /// @param newFactory The address of the new credit line factory.
    /// @param oldFactory The address of the old credit line factory.
    event SetCreditLineFactory(address newFactory, address oldFactory);

    /// @notice Emitted when the liquidity pool factory is set.
    /// @param newFactory The address of the new liquidity pool factory.
    /// @param oldFactory The address of the old liquidity pool factory.
    event SetLiquidityPoolFactory(address newFactory, address oldFactory);

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the credit line factory is not configured.
    error CreditLineFactoryNotConfigured();

    /// @notice Thrown when the liquidity pool factory is not configured.
    error LiquidityPoolFactoryNotConfigured();

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @notice Initializer of the upgradable contract.
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

    /// @notice Pauses the contract.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the credit line factory.
    /// @param newFactory The address of the new credit line factory.
    function setCreditLineFactory(address newFactory) external onlyOwner {
        if (_creditLineFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit SetCreditLineFactory(newFactory, _creditLineFactory);

        _creditLineFactory = newFactory;
    }

    /// @notice Sets the liquidity pool factory.
    /// @param newFactory The address of the new liquidity pool factory.
    function setLiquidityPoolFactory(address newFactory) external onlyOwner {
        if (_liquidityPoolFactory == newFactory) {
            revert Error.AlreadyConfigured();
        }

        emit SetLiquidityPoolFactory(newFactory, _liquidityPoolFactory);

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

        address creditLine =
            ICreditLineFactory(_creditLineFactory).createCreditLine(_market, msg.sender, token, kind, "0x");

        ILendingMarket(_market).registerCreditLine(msg.sender, creditLine);
    }

    /// @inheritdoc ILendingRegistry
    function createLiquidityPool(uint16 kind) external whenNotPaused {
        if (_liquidityPoolFactory == address(0)) {
            revert LiquidityPoolFactoryNotConfigured();
        }

        address liquidityPool =
            ILiquidityPoolFactory(_liquidityPoolFactory).createLiquidityPool(_market, msg.sender, kind, "0x");

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

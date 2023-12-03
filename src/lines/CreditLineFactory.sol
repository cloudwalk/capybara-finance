// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {ICreditLine} from "../interfaces/core/ICreditLine.sol";
import {ICreditLineFactory} from "../interfaces/ICreditLineFactory.sol";
import {CreditLineConfigurable} from "./CreditLineConfigurable.sol";

/// @title CreditLineFactory contract
/// @notice Implementation of the credit line factory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract CreditLineFactory is OwnableUpgradeable, PausableUpgradeable, ICreditLineFactory {
    /************************************************
     *  Errors
     ***********************************************/

    /// @notice Thrown when the requested credit line kind is not supported
    error UnsupportedKind();

    /************************************************
     *  Initializers
     ***********************************************/

    /// @notice Initializer of the upgradable contract
    /// @param registry_ The address of the associated lending market
    function initialize(address registry_) external initializer {
        __CreditLineFactory_init(registry_);
    }

    /// @notice Internal initializer of the upgradable contract
    /// @param registry_ The address of the associated lending market
    function __CreditLineFactory_init(address registry_) internal onlyInitializing {
        __Ownable_init_unchained(registry_);
        __Pausable_init_unchained();
        __CreditLineFactory_init_unchained();
    }

    /// @notice Unchained internal initializer of the upgradable contract
    function __CreditLineFactory_init_unchained() internal onlyInitializing {}

    /************************************************
     *  Functions
     ***********************************************/

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ICreditLineFactory
    function createCreditLine(address market, address lender, address token, uint16 kind, bytes calldata data)
        external
        onlyOwner
        returns (address)
    {
        if (kind != 1) {
            revert UnsupportedKind();
        }

        CreditLineConfigurable creditLine = new CreditLineConfigurable();
        creditLine.initialize(market, lender, token);

        emit CreateCreditLine(market, lender, token, kind, address(creditLine));

        return address(creditLine);
    }

    /// @inheritdoc ICreditLineFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}

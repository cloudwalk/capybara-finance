// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";
import { ICreditLineFactory } from "../common/interfaces/ICreditLineFactory.sol";

import { CreditLineConfigurable } from "./CreditLineConfigurable.sol";

/// @title CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Implementation of the credit line factory contract.
contract CreditLineFactory is OwnableUpgradeable, ICreditLineFactory {
    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @notice Thrown when the requested credit line kind is not supported.
    error UnsupportedKind();

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @notice Initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function initialize(address registry_) external initializer {
        __CreditLineFactory_init(registry_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function __CreditLineFactory_init(address registry_) internal onlyInitializing {
        __Ownable_init_unchained(registry_);
        __CreditLineFactory_init_unchained();
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    function __CreditLineFactory_init_unchained() internal onlyInitializing { }

    // -------------------------------------------- //
    //  Functions                                   //
    // -------------------------------------------- //

    /// @inheritdoc ICreditLineFactory
    function createCreditLine(
        address market,
        address lender,
        address token,
        uint16 kind,
        bytes calldata data
    ) external onlyOwner returns (address) {
        if (kind != 1) {
            revert UnsupportedKind();
        }

        CreditLineConfigurable creditLine = new CreditLineConfigurable();
        creditLine.initialize(market, lender, token);

        emit CreditLineCreated(market, lender, token, kind, address(creditLine));

        return address(creditLine);
    }

    /// @inheritdoc ICreditLineFactory
    function supportedKinds() external pure override returns (uint16[] memory) {
        uint16[] memory kinds = new uint16[](1);
        kinds[0] = 1;
        return kinds;
    }
}

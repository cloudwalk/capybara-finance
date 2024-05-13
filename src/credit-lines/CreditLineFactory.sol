// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { ICreditLine } from "../common/interfaces/core/ICreditLine.sol";
import { ICreditLineFactory } from "../common/interfaces/ICreditLineFactory.sol";

import { CreditLineConfigurable } from "./CreditLineConfigurable.sol";

/// @title CreditLineFactory contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Implementation of the credit line factory contract.
contract CreditLineFactory is AccessControlUpgradeable, ICreditLineFactory {
    /// @dev The role of this contract owner.
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // -------------------------------------------- //
    //  Errors                                      //
    // -------------------------------------------- //

    /// @dev Thrown when the requested credit line kind is not supported.
    error UnsupportedKind();

    // -------------------------------------------- //
    //  Initializers                                //
    // -------------------------------------------- //

    /// @dev Initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function initialize(address registry_) external initializer {
        __CreditLineFactory_init(registry_);
    }

    /// @dev Internal initializer of the upgradable contract.
    /// @param registry_ The address of the lending market registry.
    function __CreditLineFactory_init(address registry_) internal onlyInitializing {
        __AccessControl_init_unchained();
        __CreditLineFactory_init_unchained(registry_);
    }

    /// @dev Unchained internal initializer of the upgradable contract.
    function __CreditLineFactory_init_unchained(address registry_) internal onlyInitializing {
        _grantRole(OWNER_ROLE, registry_);
    }

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
    ) external onlyRole(OWNER_ROLE) returns (address) {
        data; // To prevent compiler warning about unused variable

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

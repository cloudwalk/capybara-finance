// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { AccessControlExtUpgradeable } from "../common/AccessControlExtUpgradeable.sol";

/// @title AccessControlExtUpgradeableMock contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @dev Mock of the `AccessControlExtUpgradeable` contract used for testing.
contract AccessControlExtUpgradeableMock is AccessControlExtUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __AccessControlExt_init();
    }

    function mockRoleAdmin(bytes32 role, bytes32 roleAdmin) external {
        _setRoleAdmin(role, roleAdmin);
    }

    function mockRole(address user, bytes32 role) external {
        _grantRole(role, user);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}

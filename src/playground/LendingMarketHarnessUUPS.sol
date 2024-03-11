// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import { LendingMarketUUPS } from "../LendingMarketUUPS.sol";

/// @title LendingMarketHarnessUUPS contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
/// @notice Upgradeable version of the lending market contract for testing purposes.
contract LendingMarketHarnessUUPS is LendingMarketUUPS {

    mapping(address => bool) _isHarnessAdmin;

    mapping(uint256 => uint256) _loanIdToTimestamp;

    modifier onlyHarnessAdmin {
        require(_isHarnessAdmin[msg.sender], "Caller is not a harness admin");
        _;
    }

    function playground_setHarnessAdmin(address account, bool isHarnessAdmin) external onlyOwner {
        _isHarnessAdmin[account] = isHarnessAdmin;
    }

    function playground_setLoanIdTimestamp(uint256 loanId, uint256 timestamp) external onlyHarnessAdmin {
        _loanIdToTimestamp[loanId] = timestamp;
    }

    function playground_getHarnessAdmin(address account) external view returns (bool) {
        return _isHarnessAdmin[account];
    }

    function playground_getLoanIdTimestamp(uint256 loanId) external view returns (uint256) {
        return _loanIdToTimestamp[loanId];
    }

    function _blockTimestamp(uint256 loanId) internal view override returns (uint256) {
        uint256 timestamp = _loanIdToTimestamp[loanId];
        if (timestamp == 0) {
            return super._blockTimestamp(loanId);
        }
        return timestamp;
    }
}
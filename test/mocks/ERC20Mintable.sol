// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ERC20Mintable contract
/// @notice Mintable ERC20 token contract used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract ERC20Mintable is ERC20 {
    constructor(uint256 amount) ERC20("ERC20 Test", "TEST") {
        _mint(msg.sender, amount * 10 ** decimals());
    }

    /// @notice Mints tokens
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

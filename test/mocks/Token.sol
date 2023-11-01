// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor(uint256 amount) ERC20("CapybaraFinanceToken", "CAPY") Ownable(msg.sender) {
        _mint(msg.sender, amount * 10 ** decimals());
    }
}

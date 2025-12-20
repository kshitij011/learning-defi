// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address to, uint amount) external {
        require(balanceOf(to) < 1001, "You have enough balance");
        _mint(to, amount);
    }
}

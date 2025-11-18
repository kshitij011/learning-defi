// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token0 is ERC20{

    // constructor(String name, )ERC20("Token0", "TKZ")

    constructor(string memory _name) ERC20(_name, "TKN"){
    }
    function mint(uint amount) public {
        _mint(msg.sender, amount);
    }
}
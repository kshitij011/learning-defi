// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./CurveSwap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Swap is CurveSwap {
    using SafeERC20 for IERC20;

    address public owner;

    mapping(address => mapping(address => uint)) balances;

    constructor() {
        owner = msg.sender;
    }

    function deposit(address _token, uint _amount) external {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        balances[msg.sender][_token] += _amount;
    }

    function withdraw(address _token, uint _amount) external {
        require(balances[msg.sender][_token] >= _amount, "insufficient");
        balances[msg.sender][_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function swap(address _tokenIn, address _tokenOut, uint _amount) external {
        require(balances[msg.sender][_tokenIn] >= _amount, "insufficient");

        uint indexIn;
        uint indexOut;
        bool foundIn;
        bool foundOut;

        for (uint i = 0; i < TOKENS.length; i++) {
            if (TOKENS[i] == _tokenIn) {
                indexIn = i;
                foundIn = true;
            }
            if (TOKENS[i] == _tokenOut) {
                indexOut = i;
                foundOut = true;
            }
        }

        require(foundIn && foundOut, "unsupported token");

        uint balanceBefore = IERC20(_tokenOut).balanceOf(address(this));
        initialSwap(indexIn, indexOut, _amount);
        uint balanceAfter = IERC20(_tokenOut).balanceOf(address(this));

        uint amountOut = balanceAfter - balanceBefore;

        balances[msg.sender][_tokenIn] -= _amount;
        balances[msg.sender][_tokenOut] += amountOut;
    }

    function getBalance(
        address user,
        address token
    ) external view returns (uint) {
        return balances[user][token];
    }
}

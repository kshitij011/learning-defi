// understanding curve stable swap AMM
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IERC20 {
    function balanceOf(address) external view returns (uint);
    function transferFrom(address, address, uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function approve(address, uint) external returns (bool);
}

contract MintStableSwap {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public A; // A is amplification coefficient scaled by 1e3
    uint public fee; // fee in ppm(parts per million), e.g 400 = 0.04%
    uint public FEE_DENOM; // For further calculations

    uint public totalSupply; //LP tokens total supply
    mapping(address => uint) balanceOfLP;

    uint public reserve1;
    uint public reserve0;

    constructor(address _t0, address _t1, uint _A, uint _fee) {
        token0 = IERC20(_t0);
        token1 = IERC20(_t1);
        A = _A;
        fee = _fee;
    }

    function _updateReserves() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token0.balanceOf(address(this));
    }

    function _getD(uint x, uint y) internal view returns (uint D) {
        uint S = x + y;

        // assume
        D = S;

        uint Ann = A * 2;

        for (uint i = 0; i < 64; i++) {
            // D_P measures imbalance between tokens in the pool
            uint D_P = (D * D) / (x * y * 2 + 1);

            uint Dprev = D;

            // Newton iteration
            uint256 numerator = (Ann * S + D_P * 2) * D;
            uint denominator = (Ann - 1) * D + 3 * D_P;

            D = numerator / denominator;

            if (D > Dprev) {
                if (D - Dprev <= 1) break;
            } else {
                if (Dprev - D <= 1) break;
            }
        }
        return D;
    }

    function addLiquidity(
        uint amount0,
        uint amount1
    ) external returns (uint lpMinted) {
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        _updateReserves();

        // getD D is the value of tokens in the pool, is it not constant, adjusts itself to keep prices stable
        // get new and old (before tokens were transferred)
        uint oldD = _getD(reserve0 - amount0, reserve1 - amount1);
        uint newD = _getD(reserve0, reserve1);

        if (totalSupply == 0) {
            lpMinted = newD;
            totalSupply == newD;
            balanceOfLP[msg.sender] += lpMinted;
        } else {
            // mint proportional to change in D, if D increases by certain %, same will be minted
            lpMinted = (totalSupply * (newD - oldD)) / oldD;
            totalSupply += lpMinted;
            balanceOfLP[msg.sender] += lpMinted;
        }
    }

    function removeLiquidity(
        uint lpBurn
    ) external returns (uint out0, uint out1) {
        require(balanceOfLP[msg.sender] >= lpBurn, "Insufficient funds");

        // calculating shares of amounts out
        uint share = (lpBurn * 1e18) / totalSupply;
        out0 = (reserve0 * share) / 1e18;
        out1 = (reserve1 * share) / 1e18;

        balanceOfLP[msg.sender] -= lpBurn;
        totalSupply -= lpBurn;

        token0.transfer(msg.sender, out0);
        token1.transfer(msg.sender, out1);

        _updateReserves();
    }

    function swap(
        uint8 tokenIndex,
        uint amountIn,
        uint minAmountOut
    ) external returns (uint amountOut) {
        if (tokenIndex == 0) {
            token0.transferFrom(msg.sender, address(this), amountIn);
        } else {
            token1.transferFrom(msg.sender, address(this), amountIn);
        }

        _updateReserves();

        uint x = reserve0;
        uint y = reserve1;

        // remove amountIn from the opposite balance
        if (tokenIndex == 0) {
            x = x;
        } else {
            y = y;
        }

        // D before fees
        uint D = _getD(reserve0, reserve1);

        // apply fee to amuntIn     e.g: if amountIn = 1000, this will be 999.6 if fee is 0.04%
        uint amountInAfterFee = (amountIn * (FEE_DENOM - fee)) / FEE_DENOM;

        // New balance after adding effective amountIn
        uint256 xNew = (tokenIndex == 0)
            ? reserve0 + amountInAfterFee
            : reserve0;
        uint256 yNew = (tokenIndex == 0)
            ? reserve1
            : reserve1 + amountInAfterFee;

        uint yFinal = yNew;

        // Iterate to find y such that _getD(xNew, y) == approx(D)
        for (uint i = 0; i < 64; i++) {
            uint Dcalc = _getD(xNew, yFinal);
            if (Dcalc > D) {
                uint diff = Dcalc - D;
                yFinal -= diff / (2 + A);
            } else {
                uint diff = D - Dcalc;
                yFinal += diff / (2 + A);
            }
            if (yFinal <= 1) break;
        }

        if (tokenIndex == 0) {
            amountOut = reserve1 > yFinal ? (reserve1 - yFinal) : 0;
            require(amountOut >= minAmountOut, "Slippage");
            token1.transfer(msg.sender, yFinal);
        } else {
            amountOut = reserve0 > yFinal ? (reserve0 - yFinal) : 0;
            require(amountOut >= minAmountOut, "Slippage");
            token0.transfer(msg.sender, yFinal);
        }

        _updateReserves();
    }

    function setA(uint _setA) external returns (uint) {
        // if(msg.sender == owner) {
        //     A = _setA;
        // }
        A = _setA;
        return A;
    }

    function setFee(uint _fee) external returns (uint) {
        fee = _fee;
        return fee;
    }
}

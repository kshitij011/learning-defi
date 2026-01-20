// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

pragma experimental ABIEncoderV2;

import "./interfaces/dydx/DydxFlashloanBase.sol";
import "./interfaces/dydx/ICallee.sol";

contract TestDyDxSoloMargin is ICallee, DyDxFlashloanBase {
    address private constant SOLO = 0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;

    address public flashUser;

    event Log(string message, uint value);

    struct MyCustomData {
        address token;
        uint repayAmount;
    }

    function initiateFlashLoan(address _token, uint _amount) external {
        // pass token id (1, 2. 3) for the token we need to borrow.
        // token id's
        /*0: WETH
        1: SAI
        2: USDC
        3: DAI*/
        uint marketId = _getMarketIdFromTokenAddress(SOLO, _token);

        // Calculate repay amount (_amount + (2 wei))
        uint repayAmount = _getRepaymentAmountInternal(amount);
        IERC20(_token).approve(SOLO, repayAmount);

        // to request a flash loan on dydx we need to create three actions withdraw, calling callFunction(), deposite back.
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        operations[0] = _getWithdrawAction(marketId, _amount);
        operations[1] = _getCallAction(
            abi.encode(MyCustomData({token: _token, repayAmount: repayAmount}))
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new AccountInfo[](1);
        accountInfos[0] = _getAccountInfo();

        solo.operate(accountInfos, operations);
    }

    // DyDx will callback this function when the flash loan is initiated.
    function callFunction(address sender, Account.info memory account, bytes memory data) public override {
        require(msg.sender == SOLO, "!solo");
        require(sender == address(this), "!this contract");

        MyCustomData memory mcd = abi.decode(data, (MyCustomData));
        uint repayAmount = mcd.repayAmount;

        uint bal = IERC20(mcd.token).balanceOf(address(this));
        require(bal >= repayAmount, "bal < repayamount");

        // More custom code here
        flashUser = sender;
        emit Log("bal", bal);
        emit Log("repay", repayAmount);
        emit Log("bal - repay", bal - repayAmount);
    }
}
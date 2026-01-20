# DyDx Flash Loans

## Purpose

The purpose of using DyDx flash loans over other protocols like uniswap, aave is that the trading fees are very low, 2 wei per flash loan.

The DyDx code is complex to understand because we’re composing a sequence of low-level margin actions that must net out to zero by the end of the transaction.

Big Picture: How dYdX Flash Loans Work

dYdX does not have a flashLoan() function like Aave.

Instead, it has a general margin engine (SoloMargin) that lets us:

-   Withdraw assets
-   Execute arbitrary logic
-   Deposit assets back

All **within one atomic transaction**.

If the account ends up solvent at the end → success
If not → entire transaction reverts

This is why dYdX flash loans are implemented as:

```bash
Withdraw → Call → Deposit
```

## initiateFlashLoan(): Full Mental Model

```bash
function initiateFlashLoan(address _token, uint _amount) external
```

We are asking SoloMargin to temporarily give us \_amount of \_token.

### Step 1: Find the Market ID

```bash
uint marketId = _getMarketIdFromTokenAddress(SOLO, _token);
```

dYdX does not identify assets by address.

Instead, it uses market IDs:

| Market ID | Token |
| --------- | ----- |
| 0         | WETH  |
| 1         | SAI   |
| 2         | USDC  |
| 3         | DAI   |

So this converts:

> token address → internal dYdX market ID

### Step 2: Calculate Repayment Amount

```bash
uint repayAmount = _getRepaymentAmountInternal(amount);
```

dYdX charges **2 wei** per flash loan.

So:

```bash
repayAmount = amount + 2
```

Then approve SoloMargin to pull repayment later:

```bash
IERC20(_token).approve(SOLO, repayAmount);
```

This approval is required because we deposit manually in the final step.

### Step 3: Actions — The Core of dYdX Flash Loans

```bash
Actions.ActionArgs;
```

This is where the “magic” happens.

**❓ What is Actions?**

It is a library + enum + struct definitions from dYdX’s SoloMargin contracts.
Think of it as:

-   A standardized instruction format that tells SoloMargin what to do.

**Actions.ActionArgs (Important)**

Each ActionArgs represents one instruction executed sequentially.
Internally, it looks roughly like:

```bash
struct ActionArgs {
    ActionType actionType;
    uint accountId;
    Types.AssetAmount amount;
    uint primaryMarketId;
    uint secondaryMarketId;
    address otherAddress;
    uint otherAccountId;
    bytes data;
}
```

We don’t construct this manually.
The helper functions does it for us.

### The Three Actions

1. Action 0: Withdraw

```bash
operations[0] = _getWithdrawAction(marketId, _amount);
```

Meaning:
“Take \_amount of token from SoloMargin and send it to this contract”
This is where the flash loan actually happens.

2. Action 1: Call (Callback Hook)

```bash
operations[1] = _getCallAction(
    abi.encode(MyCustomData({token: _token, repayAmount: repayAmount}))
);
```

This tells SoloMargin:

> “Call callFunction() on this contract and pass this data”

This is the execution phase:

-   Arbitrage
-   Liquidation
-   MEV
-   Any DeFi logic

⚠️ This happens **after withdraw** and **before deposit**

3. Action 2: Deposit

```bash
operations[2] = _getDepositAction(marketId, repayAmount);
```

Meaning:
“Take repayAmount tokens from this contract and give them back to SoloMargin”
If contract doesn’t have enough tokens → revert

### Step 4: Account.Info — What Is This?

```bash
Account.Info;
accountInfos[0] = _getAccountInfo();
```

**❓ What is Account?**

Account is a struct definition from dYdX

```bash
struct Info {
    address owner;
    uint256 number;
}
```

This represents a margin account inside SoloMargin.

**Why Is This Needed?**
dYdX supports:

-   Multiple accounts per address
-   Cross-margin positions

It says:

> “Run these actions on my account”

Our helper function usually sets:

```bash
owner = address(this)
number = 0
```

Meaning:

> “Use account #0 owned by this contract”

### Step 5: The Actual Execution

```bash
solo.operate(accountInfos, operations);
```

This single call:

-   Executes Withdraw
-   Executes callFunction
-   Executes Deposit
-   Checks solvency
-   Reverts everything if anything fails

⚠️ This is why flash loans are atomic.

## callFunction(): The Callback

```bash
function callFunction(
    address sender,
    Account.Info memory account,
    bytes memory data
)
```

This is called only during operate().

**Security Checks**

```bash
require(msg.sender == SOLO);
require(sender == address(this));
```

Ensures:
Only SoloMargin can call
Only your own flash loan triggered it

**Decode Custom Data**

```bash
MyCustomData memory mcd = abi.decode(data, (MyCustomData));
```

This is how you pass context into your flash loan logic.

**Balance Check**

```bash
uint bal = IERC20(mcd.token).balanceOf(address(this));
require(bal >= repayAmount);
```

This guarantees:

> “I can repay the loan + fee”
> If not → entire transaction reverts.

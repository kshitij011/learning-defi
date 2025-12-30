# Vaults

### Concepts covered:

- Implemented tokenized vault smart contract using ERC4626 standard.
- Custom Vault contracts for fees and yeild hooks.

## Notes

Valuts are widely used in DeFi protocols

### What are vaults?

- A vault is a smart contract that accepts deposits of underlying assets usually ERC20 standards.
- And then attempts to generate yeild on ERC20 token by executing various strategies.
- Vault mints shares to the depositor, proportional to deposited amount of tokens.
- Generates yeild on asset through strategies.
- Shares appreciate when yeilds are generated.
- These shares are also ERC20 and represent depositor's share of the overall vault funds including profits and yeilds on those funds.
- Users can withdraw their assets by redeeming shares.

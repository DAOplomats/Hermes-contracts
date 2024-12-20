<p align="center">
 <img src="daoplomats.png" alt="logo"  width="100"/>
</p>

<h1 align="center">HERMES</h1>

> Hermes smart contracts manage token delegation and staking, particularly designed for 1inch token staking with support for sub-delegation of voting power.

## Overview

The Hermes smart contracts consists of three main contracts that work together to enable flexible token staking and voting power delegation:

1. **HermesProxyFactory**: Creates and manages Hermes contract instances
2. **Hermes**: Handles Envoys and lead delegation
3. **Envoy**: Manages token staking and sub-delegation of voting power

## Architecture

```
HermesProxyFactory
↓
Hermes
↓
Envoy(s)
```

- `HermesProxyFactory` deploys and funds new Hermes contracts
- Each `Hermes` contract can manage multiple `Envoy` contracts
- `Envoy` contracts handle individual staking and sub-delegations

## Key Features

- CREATE2-based proxy deployment for deterministic addresses
- Support for 1inch token staking
- Hierarchical delegation structure with lead delegatee and sub-delegators
- Early withdrawal options with configurable loss parameters
- Maximum limits for sub-delegators and staking duration
- Safe token handling using OpenZeppelin's SafeERC20

## Core Contracts

### HermesProxyFactory

The entry point for creating new Hermes instances. It handles:

- Deployment of new Hermes contracts
- Initial funding of contracts with tokens
- Token recall functionality
- Address calculation for deployed contracts

### Hermes

The main contract managing delegation relationships. Features include:

- Sub-delegation management
- Token staking control
- Envoy contract deployment
- Multi-delegation support
- Recall mechanisms for staked tokens

### Envoy

Handles individual sub-delegations with features for:

- Token staking with 1inch protocol
- Snapshot delegation management
- Early withdrawal calculations
- Token recall functions

## Recalling Tokens

Tokens can be recalled through several methods:

- Standard recall: `recall(address envoy, address to)`
- Early recall with loss parameters: `recallEarly(address envoy, address to, uint256 minReturn, uint256 maxLoss)`
- Recall all delegations: `recallAll(address to)`

## Security Considerations

- All contracts use OpenZeppelin's SafeERC20 for token operations
- Maximum limits for sub-delegators and durations
- Early withdrawal protections with configurable loss parameters

## Testing & Deployments

The contracts have been tested on the Optimism Sepolia testnet and are ready for deployment on the Ethereum mainnet depending on the audit results.

- **Fake 1inch Token** (1INCH) - [0xd44390c5f4e3558be11bbdeb9c3193b6f4dff8c4](https://sepolia-optimism.etherscan.io/address/0xd44390c5f4e3558be11bbdeb9c3193b6f4dff8c4)
- **HermesProxyFactory** - [0x6f60e583e17721ecdfdab5f4251726774af6fa10](https://sepolia-optimism.etherscan.io/address/0x6f60e583e17721ecdfdab5f4251726774af6fa10)

> **Transactions**
>
> 1. Approve 1INCH tokens for HermesProxyFactory - [Link](https://sepolia-optimism.etherscan.io/tx/0xff32836bbf95513d24e12b1b1ae0e7fc4c9cbb253646af3a6efefe4f0bb5521d)
> 2. Fund and Deploy Hermes - [Link](https://sepolia-optimism.etherscan.io/tx/0x6ebef20299ce04f709cfb6f04c09ac018e9bfaed1a63cff6d58f4ce3bc2f20e7)
> 3. Subdelegate - [Link](https://sepolia-optimism.etherscan.io/tx/0xbff75a3b3b3fb2d2b788416f8832c8d61bca95ff6ac8e2ded2e6865bb2512a8b)
> 4. Subdelegate Multiple - [Link](https://sepolia-optimism.etherscan.io/tx/0xef49319a1a0e0250f90665d2b2c40baf4e49d1ca13889da1ccc150968fb305ec)
> 5. Recall All - [Link](https://sepolia-optimism.etherscan.io/tx/0xd72db5ebceb0f9c75c138d5ef569cae710143a6697483ca0082d0cb2cf2ef01f)
> 6. Recall Early - [Link](https://sepolia-optimism.etherscan.io/tx/0x72b10eee78f796060d05f2a83e23da1b302d7b5dbc237fa13cc87ecd01c5a705)
> 7. Recall - [Link](https://sepolia-optimism.etherscan.io/tx/0x507bad38514fdb3d4ac0a9c48f3859293fc723327cef559b24f27d4a6d7c43bb)

## License

LGPL-3.0-only

## Author

Anoy Roy Chowdhury - <anoy@daoplomats.org>

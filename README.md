<center><img src="daoplomats.png" alt="logo"  width="100"/> </center>

<center> <h1>HERMES</h1>

> Hermes smart contracts manage token delegation and staking, particularly designed for 1inch token staking with support for sub-delegation of voting power.

</center>

## Overview

The Hermes smart contracts consists of three main contracts that work together to enable flexible token staking and voting power delegation:

1. **HermesProxyFactory**: Creates and manages Hermes contract instances
2. **Hermes**: Handles Envoys and lead delegation
3. **Envoy**: Manages token staking and sub-delegation of voting power

## Architecture

<center>

```
HermesProxyFactory
↓
Hermes
↓
Envoy(s)
```

</center>

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

## License

LGPL-3.0-only

## Author

Anoy Roy Chowdhury - <anoy@daoplomats.org>

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- **Install dependencies**: `yarn install`
- **Compile contracts**: `npx hardhat compile`
- **Run tests**: `npx hardhat test`
- **Deploy to Ethereum mainnet**: `npx hardhat run --network mainnet ./scripts/deploy.ts`
- **Deploy to Arbitrum**: `npx hardhat run --network arbitrum ./scripts/deploy.ts`
- **Contract verification**: `npx hardhat verify --network NETWORK_NAME CONTRACT_ADDRESS "CONSTRUCTOR_ARGUMENT_1" "CONSTRUCTOR_ARGUMENT_2"`

## Architecture Overview

This is a THORSwap EVM smart contracts repository containing aggregator contracts for cross-chain swaps and DeFi integrations. The architecture follows a modular design with several key components:

### Core Contract Structure

- **Abstract Base Contracts** (`src/contracts/abstract/`): Base aggregator contracts (TSAggregator_V1 through V6) that provide common functionality including fee management, ownership, and reentrancy protection
- **Concrete Aggregators** (`src/contracts/aggregators/`): Implementation contracts for specific DEX integrations:
  - Generic aggregators for flexible swap routing
  - Uniswap V2/V3 specific aggregators with different fee tiers
  - WooFi integration aggregators
  - Chainflip cross-chain aggregators including Hyperliquid integration
  - Thorchain router integrations
- **Token Contracts** (`src/contracts/tokens/`): THOR ecosystem tokens (THOR, uTHOR, vTHOR, yTHOR, yieldTHOR)
- **Utility Contracts** (`src/contracts/misc/`): Fee distributors, oracles, and token transfer proxies
- **Wrapper Contracts** (`src/contracts/wrappers/`): Convenience wrappers for complex interactions

### Key Design Patterns

- **Upgradeable Architecture**: Multiple versions of aggregator contracts exist (V1-V6) for iterative improvements
- **Fee Management**: All aggregators inherit fee collection capabilities with 10% maximum fee limit
- **Proxy Pattern**: Uses TSAggregatorTokenTransferProxy for secure token transfers
- **Multi-chain Support**: Configured for Ethereum, Arbitrum, Base, BSC, Polygon, Optimism, and Avalanche

### Dependencies

- Uses OpenZeppelin contracts for security primitives
- Hardhat for development, testing, and deployment
- Custom libraries for safe transfers, ownership management, and reentrancy protection
- TypeChain for type-safe contract interactions

### Testing

- Tests are written in TypeScript using Hardhat framework
- Located in `/test` directory with contract-specific test files
- Mock contracts available in `src/contracts/mock/` for testing purposes

### Deployment

- Network configurations defined in `hardhat.config.ts`
- Deployment scripts in `/scripts` directory
- Requires environment variables for private keys and API keys
- Contract addresses for deployed instances documented in `deployment.md`

### Important Notes

- Some contracts were audited (see `/audits` folder), others were not
- Contract source may differ from deployed versions - this repo centralizes current versions
- Fee limits are enforced at the contract level (max 10%)
- All aggregators support ETH and ERC20 token swaps with built-in slippage protection
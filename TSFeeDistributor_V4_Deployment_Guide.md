# TSFeeDistributor_V4 Deployment Guide

## Overview

TSFeeDistributor_V4 is a two-phase fee distribution contract that prevents double-dipping vulnerabilities while distributing USDC fees to treasury and community tokens (uThor, yThor, vThor) and RUNE to thorPool.

## Prerequisites

### Environment Setup

1. **Node.js Dependencies**
   ```bash
   yarn install
   ```

2. **Environment Variables**
   Create `.env` file with:
   ```env
   TS_DEPLOYER_PRIVATE_KEY=<deployer_private_key>
   TS_DEPLOYER_PUBLIC_ADDRESS=<deployer_public_address>
   ETHERSCAN_API_KEY=<etherscan_api_key>
   INFURA_API_KEY=<infura_api_key>
   ```

### Required Contract Addresses

The deployment uses the following Ethereum mainnet addresses from `addresses.ts`:

| Contract | Address | Purpose |
|----------|---------|---------|
| ETH_TC_ROUTER_V4 | `0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146` | Thorchain Router V4 |
| ETH_USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | Fee asset (USDC) |
| ETH_TS_TREASURY | `0xC85feF7A1b039A9e080aadf80FF6f1536DADa088` | Treasury wallet |
| ETH_THOR | `0xa5f2211B9b8170F694421f2046281775E8468044` | THOR token |
| ETH_UTHOR | `0x34DeFF97889f3A6A483E3b9255cAFCB9a6e03588` | uTHOR token |
| ETH_VTHOR | `0x815C23eCA83261b6Ec689b60Cc4a58b54BC24D8D` | vTHOR token |
| ETH_YTHOR | `0x8793CD69895C45b2d2474236b3Cb28FC5C764775` | yTHOR token |

## Deployment Steps

### 1. Compile Contracts
```bash
npx hardhat compile
```

### 2. Deploy to Network

**Ethereum Mainnet:**
```bash
npx hardhat run --network mainnet ./scripts/deploy-TSFeeDistributor_V4.ts
```

**Local Testing:**
```bash
npx hardhat run ./scripts/deploy-TSFeeDistributor_V4.ts
```

### 3. Verify Deployment

The script automatically verifies the contract on Etherscan if deployed to mainnet.

Manual verification:
```bash
npx hardhat verify --network mainnet <CONTRACT_ADDRESS> \
  "0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146" \
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48" \
  "0xC85feF7A1b039A9e080aadf80FF6f1536DADa088" \
  "0xa5f2211B9b8170F694421f2046281775E8468044" \
  "0x34DeFF97889f3A6A483E3b9255cAFCB9a6e03588" \
  "0x815C23eCA83261b6Ec689b60Cc4a58b54BC24D8D" \
  "0x8793CD69895C45b2d2474236b3Cb28FC5C764775"
```

## Initial Configuration

The contract deploys with these default settings:

- **Treasury Share**: 25% (2,500,000 BPS)
- **Community Share**: 75% (7,500,000 BPS)  
- **Owner**: Deployer address
- **Executors**: Automatically set from EXECUTOR_ADDRESSES array in deploy script

**Note**: V4 removed the reward threshold mechanism - distributions can happen with any balance.

## Post-Deployment Setup

### 1. Update Executor Addresses
Before deployment, update the `EXECUTOR_ADDRESSES` array in `scripts/deploy-TSFeeDistributor_V4.ts`:
```typescript
const EXECUTOR_ADDRESSES = [
  "0xYourExecutorAddress1",
  "0xYourExecutorAddress2", // Add more as needed
];
```

The deploy script automatically sets these addresses as executors.

### 2. Adjust Configuration (Optional)
```solidity
// Change fee split (must total 10,000,000)
contract.setShares(3000000, 7000000); // 30% treasury, 70% community

// Change treasury wallet
contract.setTreasuryWallet(newTreasuryAddress);

// Add/remove executors
contract.setExecutor(executorAddress, true);  // Add executor
contract.setExecutor(executorAddress, false); // Remove executor
```

### 3. Fund Contract
Transfer USDC to the contract address for fee distribution.

## Operational Workflow

### Phase 1: Cross-Chain Preparation
```solidity
contract.swapToRune(inboundAddress);
```
This function:
- Takes snapshot of current USDC balance and calculates distributions
- Swaps required USDC to RUNE/THOR via Thorchain
- Stores distribution parameters for atomic execution

### Phase 2: Distribution  
```solidity
contract.distribute();
```
This function:
- Sends USDC to treasury, uThor, and yThor
- Sends received THOR tokens to vThor
- Clears pending distribution state

### Monitoring
```solidity
// Check if ready for distribution
contract.isReadyForDistribution();

// Get pending distribution details
contract.getPendingDistribution();
```

## Security Considerations

1. **Owner Controls**: Only owner can modify configuration and cancel pending distributions
2. **Executor Controls**: Only executors can trigger distribution phases (`swapToRune()` and `distribute()`)
3. **Emergency Recovery**: Owner can recover stuck tokens (when no pending distribution)
4. **Double-Dipping Prevention**: Two-phase system prevents balance manipulation between calculation and distribution
5. **Atomic Distribution**: Phase 2 distributes all rewards simultaneously to prevent partial failures

## Gas Estimates

| Operation | Estimated Gas |
|-----------|---------------|
| Deployment | ~3,500,000 |
| swapToRune() | ~200,000 |
| distribute() | ~300,000 |
| Configuration changes | ~50,000 |

## Troubleshooting

### Common Issues

1. **"Distribution already pending"**
   - Solution: Complete Phase 2 with `distribute()` or owner cancellation with `cancelPendingDistribution()`

2. **"No pending distribution"**
   - Solution: First call `swapToRune()` to initiate Phase 1

3. **"Insufficient THOR balance for vThor rewards"**
   - Solution: Wait for cross-chain swap to complete, then call `distribute()`

4. **"No THOR balances found"**
   - Solution: Ensure THOR tokens exist in uThor, vThor, yThor, or tcRouter for BPS calculation

### Emergency Procedures

1. **Cancel Stuck Distribution** (Owner only):
   ```solidity
   contract.cancelPendingDistribution();
   ```

2. **Recover Stuck Tokens** (Owner only, no pending distribution):
   ```solidity
   contract.emergencyRecoverToken(tokenAddress, amount);
   ```

## Testing

Run the test suite:
```bash
npx hardhat test
```

Test specific functionality:
```bash
npx hardhat test --grep "TSFeeDistributor"
```

## Contract Addresses

After deployment, update `deployment.md` with:
```markdown
## Ethereum
- TSFeeDistributor V4: [CONTRACT_ADDRESS](https://etherscan.io/address/CONTRACT_ADDRESS)
```
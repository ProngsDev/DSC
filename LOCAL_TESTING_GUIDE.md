# Local Testing Guide - DSC Protocol

This guide explains how to test the DSC protocol locally using Anvil with mock price feeds.

## Quick Start

### 1. Start Local Blockchain
```bash
# Terminal 1 - Start Anvil
make anvil
```

### 2. Deploy and Test
```bash
# Terminal 2 - Deploy contracts
make deploy-local

# Check system status
make status-local

# Check current prices
make prices-local
```

## Understanding Mock Price Feeds

### Automatic Setup
When you deploy locally, the system automatically:
- ✅ Detects Anvil network (Chain ID 31337)
- ✅ Deploys `MockV3Aggregator` contracts for ETH/USD and BTC/USD
- ✅ Deploys mock ERC20 tokens (WETH, WBTC)
- ✅ Sets initial prices: ETH = $2,000, BTC = $50,000

### Mock vs Real Price Feeds
| Aspect | Local (Mock) | Testnet/Mainnet (Real) |
|--------|--------------|-------------------------|
| **Price Source** | Manually set values | Chainlink oracle network |
| **Updates** | Manual via scripts | Automatic market updates |
| **Staleness** | No automatic staleness | Built-in staleness protection |
| **Decimals** | 8 decimals (like Chainlink) | 8 decimals |

## Testing Scenarios

### Scenario 1: Basic Operations
```bash
# 1. Deploy system
make deploy-local

# 2. Check initial state
make status-local
make prices-local

# 3. Deposit collateral and mint DSC
make deposit-local    # Deposits 10 ETH as collateral
make mint-local       # Mints 5000 DSC

# 4. Check updated state
make status-local
```

### Scenario 2: Price Manipulation Testing
```bash
# Check current prices
make prices-local

# Update ETH price to $1500 (25% drop)
make update-eth-price-local

# Update BTC price to $40000 (20% drop)  
make update-btc-price-local

# Check how price changes affect health factors
make status-local
```

### Scenario 3: Liquidation Testing
```bash
# 1. Set up a position
make deposit-local
make mint-local

# 2. Simulate market crash (50% price drop)
make crash-local

# 3. Check if position becomes liquidatable
make status-local

# 4. Perform liquidation (if health factor < 1.0)
# Note: You'll need to implement liquidation in interactions
```

## Custom Price Updates

### Using Scripts Directly

**Update specific prices:**
```bash
# Set ETH to $3000
forge script script/UpdatePrices.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  --sig "updateEthPrice(int256)" 300000000000  # $3000 with 8 decimals

# Set BTC to $60000
forge script script/UpdatePrices.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  --sig "updateBtcPrice(int256)" 6000000000000  # $60000 with 8 decimals
```

**Update both prices:**
```bash
forge script script/UpdatePrices.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  --sig "updateBothPrices(int256,int256)" 300000000000 6000000000000
```

### Price Format
Remember that Chainlink price feeds use **8 decimals**:
- $2,000 = `2000e8` = `200000000000`
- $50,000 = `50000e8` = `5000000000000`

## Testing Health Factors

### Understanding Health Factor Calculation
```
Health Factor = (Collateral Value × 100) / (150 × Debt Value)
```

### Example Calculation
With 10 ETH collateral and 5000 DSC debt:
- **At $2000 ETH**: Health Factor = (10 × 2000 × 100) / (150 × 5000) = 2.67 ✅ Healthy
- **At $1000 ETH**: Health Factor = (10 × 1000 × 100) / (150 × 5000) = 1.33 ✅ Healthy  
- **At $750 ETH**: Health Factor = (10 × 750 × 100) / (150 × 5000) = 1.0 ⚠️ At Risk
- **At $700 ETH**: Health Factor = (10 × 700 × 100) / (150 × 5000) = 0.93 *** Liquidatable

### Testing Different Health Factors
```bash
# Start with healthy position
make deploy-local
make deposit-local  # 10 ETH at $2000 = $20,000 collateral
make mint-local     # 5000 DSC debt

# Test different price levels
forge script script/UpdatePrices.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --sig "updateEthPrice(int256)" 100000000000  # $1000
forge script script/UpdatePrices.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --sig "updateEthPrice(int256)" 75000000000   # $750  
forge script script/UpdatePrices.s.sol --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast --sig "updateEthPrice(int256)" 70000000000   # $700 (liquidatable)
```

## Advanced Testing

### Multi-User Testing
```bash
# Deploy system
make deploy-local

# Test with different users (change private keys)
# User 1: Default Anvil account
# User 2: Second Anvil account (0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d)
```

### Gas Usage Testing
```bash
# Run gas estimation
forge script script/GasEstimation.s.sol --rpc-url http://localhost:8545 -vvv
```

### Integration Testing
```bash
# Run comprehensive integration tests
make test-integration

# Run deployment-specific tests
forge test --match-contract DeploymentTest -vv
```

## Troubleshooting

### Common Issues

**1. "No deployment artifacts found"**
- Make sure you've deployed first: `make deploy-local`
- Check that Anvil is running on the correct port (8545)

**2. "Insufficient funds for gas"**
- Anvil provides test accounts with ETH automatically
- Use the default private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

**3. "Price feed not found"**
- Ensure you're on the correct network (Anvil, Chain ID 31337)
- Redeploy if needed: `make deploy-local`

**4. "Health factor too low"**
- Check current prices: `make prices-local`
- Increase collateral or reduce debt
- Or test liquidation scenarios

### Useful Commands
```bash
# Check Anvil accounts
cast wallet list --rpc-url http://localhost:8545

# Check ETH balance
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545

# Check contract deployment
cast code <contract-address> --rpc-url http://localhost:8545

# Monitor transactions
cast logs --rpc-url http://localhost:8545
```

## Next Steps

After local testing, you can:
1. **Deploy to Sepolia**: `make deploy-sepolia` (with real Chainlink feeds)
2. **Run comprehensive tests**: `make test`
3. **Prepare for mainnet**: Review `SECURITY_CHECKLIST.md`

---

**Remember**: Local testing uses mock price feeds that you control manually. Real networks use live Chainlink oracles that update automatically based on market conditions.

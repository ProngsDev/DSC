# DSC Deployment Guide

This guide provides comprehensive instructions for deploying the Decentralized Stablecoin (DSC) system to various networks.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Network Configurations](#network-configurations)
- [Deployment Process](#deployment-process)
- [Post-Deployment Verification](#post-deployment-verification)
- [Interaction Scripts](#interaction-scripts)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Prerequisites

### Required Tools

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- [Git](https://git-scm.com/)
- [Make](https://www.gnu.org/software/make/) (optional, for convenience commands)

### Required Accounts

- **Testnet**: Ethereum wallet with Sepolia ETH
- **Mainnet**: Ethereum wallet with sufficient ETH for gas fees
- **Etherscan API Key**: For contract verification

### Get Testnet ETH

For Sepolia testnet deployment, get free ETH from:
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)
- [Chainlink Faucet](https://faucets.chain.link/)

## Environment Setup

### 1. Clone and Setup Repository

```bash
git clone <repository-url>
cd DSC
make install
```

### 2. Environment Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` with your actual values:

```bash
# Required for testnet/mainnet deployments
PRIVATE_KEY=your_private_key_without_0x_prefix
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your_api_key
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/your_api_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### 3. Build and Test

```bash
make build
make test
```

## Network Configurations

### Supported Networks

| Network | Chain ID | Purpose | Gas Token |
|---------|----------|---------|-----------|
| Anvil (Local) | 31337 | Development | ETH |
| Sepolia | 11155111 | Testing | SepoliaETH |
| Ethereum Mainnet | 1 | Production | ETH |

### Collateral Assets

| Asset | Mainnet Address | Sepolia Address | Price Feed |
|-------|----------------|-----------------|------------|
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | `0xdd13E55209Fd76AfE204dBda4007C227904f0a81` | ETH/USD |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | `0x8f3Cf7ad23Cd3CaDbD9735aff958023239c6A063` | BTC/USD |

## Deployment Process

### Local Development (Anvil)

1. **Start Anvil**:
   ```bash
   make anvil
   ```

2. **Deploy Contracts** (in new terminal):
   ```bash
   make deploy-local
   ```

3. **Interact with Contracts**:
   ```bash
   make deposit-local
   make mint-local
   make status-local
   ```

### Sepolia Testnet

1. **Ensure Prerequisites**:
   - Sepolia ETH in your wallet
   - Valid RPC URL in `.env`
   - Private key in `.env`

2. **Deploy**:
   ```bash
   make deploy-sepolia
   ```

3. **Verify Deployment**:
   ```bash
   make status-sepolia
   ```

### Ethereum Mainnet

⚠️ **CAUTION**: Mainnet deployment uses real ETH and is irreversible.

1. **Pre-deployment Checklist**:
   - [ ] All tests pass: `make test`
   - [ ] Code reviewed and audited
   - [ ] Sufficient ETH for gas fees (estimate: 0.05-0.1 ETH)
   - [ ] Backup of private key
   - [ ] Double-check all configurations

2. **Deploy**:
   ```bash
   make deploy-mainnet
   ```

3. **Verify Deployment**:
   ```bash
   make verify-mainnet
   ```

## Post-Deployment Verification

### Automated Checks

The deployment script automatically performs:

- ✅ Contract deployment validation
- ✅ Ownership transfer verification
- ✅ Price feed configuration check
- ✅ Collateral token mapping validation

### Manual Verification

1. **Check Contract Addresses**:
   ```bash
   # View deployment artifacts
   ls broadcast/DeployDSC.s.sol/
   ```

2. **Verify on Etherscan**:
   - Navigate to deployed contract addresses
   - Confirm contract verification status
   - Check constructor parameters

3. **Test Basic Functionality**:
   ```bash
   # Check system status
   make status-<network>
   
   # Test collateral deposit (testnet only)
   make deposit-<network>
   ```

## Interaction Scripts

### Available Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `DepositCollateral` | Deposit WETH as collateral | `make deposit-<network>` |
| `MintDsc` | Mint DSC tokens | `make mint-<network>` |
| `DepositAndMint` | Deposit and mint in one tx | `make deposit-and-mint-<network>` |
| `GetSystemStatus` | View system information | `make status-<network>` |

### Custom Interactions

For custom interactions, use the Interactions contract:

```bash
forge script script/Interactions.s.sol:Interactions \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --sig "yourCustomFunction(uint256)" 1000
```

## Troubleshooting

### Common Issues

1. **"Insufficient funds for gas"**:
   - Ensure wallet has enough ETH
   - Check current gas prices: `cast gas-price`

2. **"Private key not found"**:
   - Verify `.env` file exists and has correct format
   - Ensure no `0x` prefix on private key

3. **"RPC URL not responding"**:
   - Check RPC URL validity
   - Try alternative RPC providers

4. **"Contract verification failed"**:
   - Ensure Etherscan API key is valid
   - Check compiler version matches

### Debug Commands

```bash
# Check network connection
cast chain-id --rpc-url $RPC_URL

# Check account balance
cast balance $ADDRESS --rpc-url $RPC_URL

# Estimate gas for deployment
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $RPC_URL --estimate-gas
```

## Security Considerations

### Private Key Management

- ✅ Use dedicated wallets for different networks
- ✅ Never commit `.env` files to version control
- ✅ Use hardware wallets for mainnet deployments
- ✅ Regularly rotate private keys

### Deployment Safety

- ✅ Test thoroughly on testnets first
- ✅ Use multi-signature wallets for mainnet
- ✅ Implement timelock for critical functions
- ✅ Have emergency pause mechanisms

### Network-Specific Risks

| Network | Risks | Mitigations |
|---------|-------|-------------|
| Mainnet | High gas costs, irreversible | Thorough testing, gas estimation |
| Testnet | Network instability | Multiple RPC providers, retry logic |
| Local | State resets | Persistent storage, documentation |

## Gas Optimization

### Estimated Gas Costs

| Operation | Estimated Gas | Mainnet Cost (20 gwei) |
|-----------|---------------|------------------------|
| Deploy DSC | ~800,000 | ~0.016 ETH |
| Deploy DSCEngine | ~2,500,000 | ~0.05 ETH |
| Deposit Collateral | ~100,000 | ~0.002 ETH |
| Mint DSC | ~150,000 | ~0.003 ETH |

### Gas Optimization Tips

- Deploy during low network congestion
- Use CREATE2 for deterministic addresses
- Batch multiple operations
- Consider Layer 2 solutions for testing

## Support

For deployment issues:

1. Check this documentation
2. Review test files for examples
3. Check GitHub issues
4. Contact development team

---

**Remember**: Always test on testnets before mainnet deployment!

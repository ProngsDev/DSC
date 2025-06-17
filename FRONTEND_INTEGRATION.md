# Frontend Integration Guide - DSC Protocol

This guide explains how to integrate your frontend application with the locally deployed DSC protocol.

## Quick Setup

### 1. Deploy DSC Locally (Backend)
```bash
# Terminal 1: Start Anvil
make anvil

# Terminal 2: Deploy contracts
make deploy-local

# Export contract info for frontend
make export-frontend
```

### 2. Configure Your Frontend

**Get contract addresses and configuration:**
```bash
make export-frontend
```

This will output JSON configuration and environment variables you can use in your frontend.

## Network Configuration

### Anvil Local Network Settings
```javascript
// Add this network to your wallet (MetaMask, etc.)
const anvilNetwork = {
  chainId: '0x7A69', // 31337 in hex
  chainName: 'Anvil Local',
  rpcUrls: ['http://localhost:8545'],
  nativeCurrency: {
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18
  }
}
```

### Test Account
```javascript
// Import this account to your wallet for testing
const testAccount = {
  privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
  address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
  balance: '10000 ETH' // Pre-funded by Anvil
}
```

## Contract Integration

### 1. Get Contract Addresses
After running `make export-frontend`, you'll get output like:
```json
{
  "chainId": 31337,
  "networkName": "anvil",
  "contracts": {
    "DSC": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    "DSCEngine": "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    "WETH": "0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496",
    "WBTC": "0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3",
    "ETH_USD_PRICE_FEED": "0x34A1D3fff3958843C43aD80F30b94c510645C316",
    "BTC_USD_PRICE_FEED": "0x90193C961A926261B756D1E5bb255e67ff9498A1"
  }
}
```

### 2. Get ABIs
```bash
# Copy ABI files to your frontend project
make copy-abis

# ABIs will be in: frontend-exports/abis/
# - DecentralizedStableCoin.json
# - DSCEngine.json  
# - ERC20Mock.json
# - MockV3Aggregator.json
```

### 3. Frontend Environment Variables
```bash
# Add to your frontend .env file
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_NETWORK_NAME=anvil
NEXT_PUBLIC_RPC_URL=http://localhost:8545
NEXT_PUBLIC_DSC_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
NEXT_PUBLIC_DSC_ENGINE_ADDRESS=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
NEXT_PUBLIC_WETH_ADDRESS=0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
NEXT_PUBLIC_WBTC_ADDRESS=0xBb2180ebd78ce97360503434eD37fcf4a1Df61c3
```

## Frontend Code Examples

### React + ethers.js Example
```javascript
import { ethers } from 'ethers';
import DSCEngineABI from './abis/DSCEngine.json';
import DSCABI from './abis/DecentralizedStableCoin.json';
import ERC20ABI from './abis/ERC20Mock.json';

// Contract addresses (from export-frontend output)
const contracts = {
  DSC: process.env.NEXT_PUBLIC_DSC_ADDRESS,
  DSCEngine: process.env.NEXT_PUBLIC_DSC_ENGINE_ADDRESS,
  WETH: process.env.NEXT_PUBLIC_WETH_ADDRESS,
  WBTC: process.env.NEXT_PUBLIC_WBTC_ADDRESS,
};

// Connect to local Anvil
const provider = new ethers.JsonRpcProvider('http://localhost:8545');

// Contract instances
const dscEngine = new ethers.Contract(contracts.DSCEngine, DSCEngineABI.abi, provider);
const dsc = new ethers.Contract(contracts.DSC, DSCABI.abi, provider);
const weth = new ethers.Contract(contracts.WETH, ERC20ABI.abi, provider);

// Example: Deposit collateral
async function depositCollateral(signer, amount) {
  const dscEngineWithSigner = dscEngine.connect(signer);
  const wethWithSigner = weth.connect(signer);
  
  // 1. Approve WETH spending
  const approveTx = await wethWithSigner.approve(contracts.DSCEngine, amount);
  await approveTx.wait();
  
  // 2. Deposit collateral
  const depositTx = await dscEngineWithSigner.depositCollateral(contracts.WETH, amount);
  await depositTx.wait();
  
  console.log('Collateral deposited successfully!');
}

// Example: Mint DSC
async function mintDSC(signer, amount) {
  const dscEngineWithSigner = dscEngine.connect(signer);
  
  const mintTx = await dscEngineWithSigner.mintDSC(amount);
  await mintTx.wait();
  
  console.log('DSC minted successfully!');
}

// Example: Get user's health factor
async function getHealthFactor(userAddress) {
  const healthFactor = await dscEngine.getHealthFactor(userAddress);
  return ethers.formatEther(healthFactor); // Convert from wei
}
```

### React + wagmi Example
```javascript
import { useContractRead, useContractWrite, usePrepareContractWrite } from 'wagmi';
import DSCEngineABI from './abis/DSCEngine.json';

// Get user's health factor
function useHealthFactor(userAddress) {
  return useContractRead({
    address: process.env.NEXT_PUBLIC_DSC_ENGINE_ADDRESS,
    abi: DSCEngineABI.abi,
    functionName: 'getHealthFactor',
    args: [userAddress],
  });
}

// Mint DSC
function useMintDSC() {
  const { config } = usePrepareContractWrite({
    address: process.env.NEXT_PUBLIC_DSC_ENGINE_ADDRESS,
    abi: DSCEngineABI.abi,
    functionName: 'mintDSC',
  });
  
  return useContractWrite(config);
}
```

## Testing Workflow

### 1. Start Backend
```bash
# Terminal 1: Anvil
make anvil

# Terminal 2: Deploy contracts
make deploy-local
make export-frontend
```

### 2. Start Frontend
```bash
# In your frontend repo
npm run dev
# or
yarn dev
```

### 3. Connect Wallet
1. Add Anvil network to MetaMask
2. Import test account: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
3. Connect to your frontend

### 4. Test Interactions
```bash
# Backend: Mint test tokens for frontend testing
make deposit-local  # This gives the test account WETH/WBTC

# Frontend: Now you can test:
# - Approve WETH spending
# - Deposit collateral
# - Mint DSC
# - Check health factors
# - Burn DSC
# - Redeem collateral
```

### 5. Test Price Changes
```bash
# Backend: Simulate price changes
make update-eth-price-local  # ETH to $1500
make crash-local            # 50% market crash

# Frontend: Watch how UI updates with new prices/health factors
```

## Common Integration Patterns

### 1. Real-time Price Updates
```javascript
// Listen for price updates (if you implement events)
useEffect(() => {
  const filter = dscEngine.filters.PriceUpdated();
  dscEngine.on(filter, (token, newPrice) => {
    console.log(`${token} price updated to ${newPrice}`);
    // Update your UI
  });
  
  return () => dscEngine.removeAllListeners(filter);
}, []);
```

### 2. Health Factor Monitoring
```javascript
// Poll health factor every 10 seconds
useEffect(() => {
  const interval = setInterval(async () => {
    if (userAddress) {
      const healthFactor = await getHealthFactor(userAddress);
      setHealthFactor(healthFactor);
      
      // Warn if close to liquidation
      if (parseFloat(healthFactor) < 1.1) {
        setShowLiquidationWarning(true);
      }
    }
  }, 10000);
  
  return () => clearInterval(interval);
}, [userAddress]);
```

### 3. Transaction Status
```javascript
// Handle transaction states
const [txStatus, setTxStatus] = useState('idle'); // idle, pending, success, error

async function handleDeposit() {
  try {
    setTxStatus('pending');
    const tx = await depositCollateral(signer, amount);
    await tx.wait();
    setTxStatus('success');
  } catch (error) {
    setTxStatus('error');
    console.error(error);
  }
}
```

## Debugging Tips

### 1. Check Contract Deployment
```bash
# Verify contracts are deployed
make status-local

# Get fresh addresses if redeployed
make export-frontend
```

### 2. Check Network Connection
```javascript
// Verify you're on the right network
const network = await provider.getNetwork();
console.log('Connected to chain ID:', network.chainId); // Should be 31337
```

### 3. Check Account Balance
```javascript
// Verify test account has ETH
const balance = await provider.getBalance('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266');
console.log('Account balance:', ethers.formatEther(balance), 'ETH');
```

### 4. Monitor Transactions
```bash
# Backend: Watch Anvil logs for transactions
# Frontend: Use browser dev tools to check for errors
```

## Production Considerations

When moving from local to testnet/mainnet:

1. **Update RPC URLs**: Change from `http://localhost:8545` to real network RPCs
2. **Update Contract Addresses**: Deploy to target network and update addresses
3. **Real Price Feeds**: Remove mock price feed interactions
4. **Gas Estimation**: Add proper gas estimation for real networks
5. **Error Handling**: Add robust error handling for network issues

---

This setup gives you a complete local development environment where your frontend can interact with the DSC protocol exactly as it would on a real network!

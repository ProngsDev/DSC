/**
 * Frontend Wallet Setup Helper
 * Run this in your browser console to automatically configure MetaMask for Anvil
 */

// Anvil network configuration
const ANVIL_NETWORK = {
  chainId: '0x7A69', // 31337 in hex
  chainName: 'Anvil Local',
  rpcUrls: ['http://localhost:8545'],
  nativeCurrency: {
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18
  }
};

// Anvil test accounts
const ANVIL_ACCOUNTS = [
  {
    name: 'Anvil Account #0',
    address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
    privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
  },
  {
    name: 'Anvil Account #1', 
    address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    privateKey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'
  },
  {
    name: 'Anvil Account #2',
    address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    privateKey: '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'
  }
];

/**
 * Add Anvil network to MetaMask
 */
async function addAnvilNetwork() {
  if (!window.ethereum) {
    alert('MetaMask not detected! Please install MetaMask.');
    return false;
  }

  try {
    await window.ethereum.request({
      method: 'wallet_addEthereumChain',
      params: [ANVIL_NETWORK]
    });
    console.log('✅ Anvil network added successfully!');
    return true;
  } catch (error) {
    console.error('❌ Failed to add Anvil network:', error);
    return false;
  }
}

/**
 * Switch to Anvil network
 */
async function switchToAnvil() {
  if (!window.ethereum) {
    alert('MetaMask not detected!');
    return false;
  }

  try {
    await window.ethereum.request({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: ANVIL_NETWORK.chainId }]
    });
    console.log('✅ Switched to Anvil network!');
    return true;
  } catch (error) {
    if (error.code === 4902) {
      // Network not added yet, try to add it
      return await addAnvilNetwork();
    }
    console.error('❌ Failed to switch to Anvil network:', error);
    return false;
  }
}

/**
 * Check current network
 */
async function checkNetwork() {
  if (!window.ethereum) return false;

  try {
    const chainId = await window.ethereum.request({ method: 'eth_chainId' });
    const isAnvil = chainId === ANVIL_NETWORK.chainId;
    
    console.log(`Current network: ${chainId} (${parseInt(chainId, 16)})`);
    console.log(`Connected to Anvil: ${isAnvil ? '✅' : '❌'}`);
    
    return isAnvil;
  } catch (error) {
    console.error('❌ Failed to check network:', error);
    return false;
  }
}

/**
 * Check account balance
 */
async function checkBalance(address) {
  if (!window.ethereum) return null;

  try {
    const balance = await window.ethereum.request({
      method: 'eth_getBalance',
      params: [address, 'latest']
    });
    
    const balanceEth = parseInt(balance, 16) / 1e18;
    console.log(`Balance for ${address}: ${balanceEth.toFixed(4)} ETH`);
    return balanceEth;
  } catch (error) {
    console.error('❌ Failed to check balance:', error);
    return null;
  }
}

/**
 * Get current connected accounts
 */
async function getConnectedAccounts() {
  if (!window.ethereum) return [];

  try {
    const accounts = await window.ethereum.request({ method: 'eth_accounts' });
    console.log('Connected accounts:', accounts);
    return accounts;
  } catch (error) {
    console.error('❌ Failed to get accounts:', error);
    return [];
  }
}

/**
 * Request account connection
 */
async function connectWallet() {
  if (!window.ethereum) {
    alert('MetaMask not detected! Please install MetaMask.');
    return [];
  }

  try {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    console.log('✅ Wallet connected!', accounts);
    return accounts;
  } catch (error) {
    console.error('❌ Failed to connect wallet:', error);
    return [];
  }
}

/**
 * Complete setup process
 */
async function setupAnvilWallet() {
  console.log('🚀 Setting up Anvil wallet connection...');
  
  // 1. Check if MetaMask is available
  if (!window.ethereum) {
    alert('Please install MetaMask first!');
    return false;
  }

  // 2. Add/switch to Anvil network
  const networkAdded = await switchToAnvil();
  if (!networkAdded) {
    console.log('❌ Failed to setup Anvil network');
    return false;
  }

  // 3. Connect wallet
  const accounts = await connectWallet();
  if (accounts.length === 0) {
    console.log('❌ No accounts connected');
    return false;
  }

  // 4. Check balance
  await checkBalance(accounts[0]);

  // 5. Show account info
  console.log('\n📋 Anvil Test Accounts (import these private keys):');
  ANVIL_ACCOUNTS.forEach((account, index) => {
    console.log(`\n${account.name}:`);
    console.log(`  Address: ${account.address}`);
    console.log(`  Private Key: ${account.privateKey}`);
  });

  console.log('\n✅ Setup complete! You can now:');
  console.log('1. Import test accounts using the private keys above');
  console.log('2. Use your frontend to interact with deployed contracts');
  console.log('3. Run "make export-frontend" in your DSC repo to get contract addresses');

  return true;
}

/**
 * Add token to MetaMask
 */
async function addToken(address, symbol, decimals = 18) {
  if (!window.ethereum) return false;

  try {
    await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: address,
          symbol: symbol,
          decimals: decimals,
        },
      },
    });
    console.log(`✅ ${symbol} token added to MetaMask!`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to add ${symbol} token:`, error);
    return false;
  }
}

// Export functions for use
window.anvilSetup = {
  setupAnvilWallet,
  addAnvilNetwork,
  switchToAnvil,
  checkNetwork,
  checkBalance,
  getConnectedAccounts,
  connectWallet,
  addToken,
  ANVIL_ACCOUNTS
};

// Auto-run setup if this script is executed
console.log('🔧 Anvil Wallet Setup Helper Loaded!');
console.log('Run: anvilSetup.setupAnvilWallet() to start setup');
console.log('Or run individual functions like: anvilSetup.addAnvilNetwork()');

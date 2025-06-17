# DSC Deployment Makefile
# Provides convenient commands for building, testing, and deploying the DSC system

# Load environment variables
-include .env

# Default Anvil private key for local testing
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Network RPC URLs
SEPOLIA_RPC_URL ?= https://eth-sepolia.g.alchemy.com/v2/$(ALCHEMY_API_KEY)
MAINNET_RPC_URL ?= https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_API_KEY)

.PHONY: all clean install update build test test-unit test-integration test-fuzz snapshot format lint deploy-local deploy-sepolia deploy-mainnet verify help

# Default target
all: clean install update build test

# Help target
help:
	@echo "DSC Deployment Commands:"
	@echo ""
	@echo "Setup Commands:"
	@echo "  install     - Install dependencies"
	@echo "  update      - Update dependencies"
	@echo "  build       - Compile contracts"
	@echo "  clean       - Clean build artifacts"
	@echo ""
	@echo "Testing Commands:"
	@echo "  test        - Run all tests"
	@echo "  test-unit   - Run unit tests"
	@echo "  test-integration - Run integration tests"
	@echo "  test-fuzz   - Run fuzz tests"
	@echo "  snapshot    - Generate gas snapshots"
	@echo ""
	@echo "Code Quality:"
	@echo "  format      - Format code"
	@echo "  lint        - Run linter"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  deploy-local    - Deploy to local Anvil"
	@echo "  deploy-sepolia  - Deploy to Sepolia testnet"
	@echo "  deploy-mainnet  - Deploy to Ethereum mainnet"
	@echo ""
	@echo "Interaction Commands:"
	@echo "  deposit-local   - Deposit collateral (local)"
	@echo "  mint-local      - Mint DSC (local)"
	@echo "  status-local    - Get system status (local)"
	@echo ""
	@echo "Price Feed Commands (Local Only):"
	@echo "  prices-local    - Check current mock price feed values"
	@echo "  update-eth-price-local - Update ETH price to $1500"
	@echo "  update-btc-price-local - Update BTC price to $40000"
	@echo "  crash-local     - Simulate 50% market crash"
	@echo ""
	@echo "Frontend Integration:"
	@echo "  export-frontend - Export contract addresses for frontend"
	@echo "  copy-abis       - Copy ABI files to frontend-exports/"
	@echo ""
	@echo "Verification:"
	@echo "  verify-sepolia  - Verify contracts on Sepolia"
	@echo "  verify-mainnet  - Verify contracts on Mainnet"

# Setup commands
clean:
	forge clean

install:
	forge install

update:
	forge update

build:
	forge build

# Testing commands
test:
	forge test

test-unit:
	forge test --match-path "test/DSCEngine.t.sol"

test-integration:
	forge test --match-path "test/IntegrationTests.t.sol"

test-fuzz:
	forge test --match-path "test/FuzzTests.t.sol"

test-gas:
	forge test --match-path "test/GasOptimization.t.sol"

snapshot:
	forge snapshot

# Code quality
format:
	forge fmt

lint:
	forge fmt --check

# Local development
anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Deployment commands
deploy-local:
	@echo "Deploying to local Anvil..."
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

deploy-sepolia:
	@echo "Deploying to Sepolia testnet..."
	@echo "Make sure you have PRIVATE_KEY and SEPOLIA_RPC_URL set in .env"
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy-mainnet:
	@echo "⚠️  MAINNET DEPLOYMENT ⚠️"
	@echo "This will deploy to Ethereum mainnet with real ETH!"
	@echo "Make sure you have:"
	@echo "  1. Sufficient ETH for gas fees"
	@echo "  2. Correct PRIVATE_KEY in .env"
	@echo "  3. Valid MAINNET_RPC_URL in .env"
	@echo "  4. Double-checked all contract code"
	@read -p "Type 'DEPLOY' to continue: " confirm && [ "$$confirm" = "DEPLOY" ]
	forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $(MAINNET_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# Interaction commands (local)
deposit-local:
	forge script script/Interactions.s.sol:DepositCollateral --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

mint-local:
	forge script script/Interactions.s.sol:MintDsc --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

deposit-and-mint-local:
	forge script script/Interactions.s.sol:DepositAndMint --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

status-local:
	forge script script/Interactions.s.sol:GetSystemStatus --rpc-url http://localhost:8545 -vvvv

# Price feed management (local only)
prices-local:
	forge script script/UpdatePrices.s.sol:GetCurrentPrices --rpc-url http://localhost:8545 -vvvv

update-eth-price-local:
	@echo "Updating ETH price to $$1500..."
	forge script script/UpdatePrices.s.sol:UpdateEthPrice --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

update-btc-price-local:
	@echo "Updating BTC price to $$40000..."
	forge script script/UpdatePrices.s.sol:UpdateBtcPrice --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

crash-local:
	@echo "*** Simulating 50% market crash..."
	forge script script/UpdatePrices.s.sol:SimulateMarketCrash --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast -vvvv

# Frontend integration
export-frontend:
	@echo "Exporting contract addresses and ABIs for frontend..."
	forge script script/ExportForFrontend.s.sol:ExportForFrontend --rpc-url http://localhost:8545 -vvv

copy-abis:
	@echo "Copying ABI files for frontend..."
	@mkdir -p frontend-exports/abis
	@cp out/DecentralizedStableCoin.sol/DecentralizedStableCoin.json frontend-exports/abis/
	@cp out/DSCEngine.sol/DSCEngine.json frontend-exports/abis/
	@cp out/ERC20Mock.sol/ERC20Mock.json frontend-exports/abis/
	@cp out/MockV3Aggregator.sol/MockV3Aggregator.json frontend-exports/abis/
	@echo "ABIs copied to frontend-exports/abis/"

# Interaction commands (Sepolia)
deposit-sepolia:
	forge script script/Interactions.s.sol:DepositCollateral --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

mint-sepolia:
	forge script script/Interactions.s.sol:MintDsc --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast -vvvv

status-sepolia:
	forge script script/Interactions.s.sol:GetSystemStatus --rpc-url $(SEPOLIA_RPC_URL) -vvvv

# Contract verification
verify-sepolia:
	@echo "Verifying contracts on Sepolia..."
	forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args $(shell cast abi-encode "constructor()" ) --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version v0.8.20 src/DecentralizedStableCoin.sol:DecentralizedStableCoin

verify-mainnet:
	@echo "Verifying contracts on Mainnet..."
	forge verify-contract --chain-id 1 --num-of-optimizations 200 --watch --constructor-args $(shell cast abi-encode "constructor()" ) --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version v0.8.20 src/DecentralizedStableCoin.sol:DecentralizedStableCoin

# Security analysis
slither:
	slither . --config-file slither.config.json

# Coverage
coverage:
	forge coverage

# Documentation
docs:
	forge doc

# Network info
network-info:
	@echo "Current network information:"
	@echo "Chain ID: $(shell cast chain-id)"
	@echo "Block number: $(shell cast block-number)"
	@echo "Gas price: $(shell cast gas-price)"

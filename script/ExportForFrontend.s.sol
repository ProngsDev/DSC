// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title ExportForFrontend
 * @notice Export contract addresses and network info for frontend integration
 * @dev Generates JSON files with contract addresses and ABIs for frontend use
 */
contract ExportForFrontend is Script {
    struct ContractAddresses {
        address dsc;
        address dscEngine;
        address weth;
        address wbtc;
        address ethUsdPriceFeed;
        address btcUsdPriceFeed;
        uint256 chainId;
        string networkName;
    }

    /**
     * @notice Export contract addresses to JSON format
     */
    function run() external {
        ContractAddresses memory addresses = _getContractAddresses();

        console.log("=== Contract Addresses for Frontend ===");
        console.log("Network:", addresses.networkName);
        console.log("Chain ID:", addresses.chainId);
        console.log("");
        console.log("DSC Token:", addresses.dsc);
        console.log("DSC Engine:", addresses.dscEngine);
        console.log("WETH Token:", addresses.weth);
        console.log("WBTC Token:", addresses.wbtc);
        console.log("ETH/USD Price Feed:", addresses.ethUsdPriceFeed);
        console.log("BTC/USD Price Feed:", addresses.btcUsdPriceFeed);

        _generateJsonOutput(addresses);
        _generateEnvOutput(addresses);
        _logFrontendInstructions(addresses);
    }

    /**
     * @notice Get all contract addresses from deployments
     */
    function _getContractAddresses() internal returns (ContractAddresses memory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address dscAddress = DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid);
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);

        return ContractAddresses({
            dsc: dscAddress,
            dscEngine: dscEngineAddress,
            weth: config.weth,
            wbtc: config.wbtc,
            ethUsdPriceFeed: config.wethUsdPriceFeed,
            btcUsdPriceFeed: config.wbtcUsdPriceFeed,
            chainId: block.chainid,
            networkName: helperConfig.getNetworkName()
        });
    }

    /**
     * @notice Generate JSON output for frontend consumption
     */
    function _generateJsonOutput(ContractAddresses memory addresses) internal pure {
        console.log("");
        console.log("=== JSON for Frontend (copy to your frontend config) ===");
        console.log("{");
        console.log('  "chainId":', addresses.chainId, ",");
        console.log('  "networkName": "', addresses.networkName, '",');
        console.log('  "contracts": {');
        console.log('    "DSC": "', addresses.dsc, '",');
        console.log('    "DSCEngine": "', addresses.dscEngine, '",');
        console.log('    "WETH": "', addresses.weth, '",');
        console.log('    "WBTC": "', addresses.wbtc, '",');
        console.log('    "ETH_USD_PRICE_FEED": "', addresses.ethUsdPriceFeed, '",');
        console.log('    "BTC_USD_PRICE_FEED": "', addresses.btcUsdPriceFeed, '"');
        console.log("  }");
        console.log("}");
    }

    /**
     * @notice Generate environment variables for frontend
     */
    function _generateEnvOutput(ContractAddresses memory addresses) internal pure {
        console.log("");
        console.log("=== Environment Variables for Frontend ===");
        console.log("# Add these to your frontend .env file");
        console.log("NEXT_PUBLIC_CHAIN_ID=", addresses.chainId);
        console.log("NEXT_PUBLIC_NETWORK_NAME=", addresses.networkName);
        console.log("NEXT_PUBLIC_RPC_URL=http://localhost:8545");
        console.log("NEXT_PUBLIC_DSC_ADDRESS=", addresses.dsc);
        console.log("NEXT_PUBLIC_DSC_ENGINE_ADDRESS=", addresses.dscEngine);
        console.log("NEXT_PUBLIC_WETH_ADDRESS=", addresses.weth);
        console.log("NEXT_PUBLIC_WBTC_ADDRESS=", addresses.wbtc);
        console.log("NEXT_PUBLIC_ETH_USD_PRICE_FEED=", addresses.ethUsdPriceFeed);
        console.log("NEXT_PUBLIC_BTC_USD_PRICE_FEED=", addresses.btcUsdPriceFeed);
    }

    /**
     * @notice Log frontend integration instructions
     */
    function _logFrontendInstructions(ContractAddresses memory addresses) internal pure {
        console.log("");
        console.log("=== Frontend Integration Instructions ===");
        console.log("1. Configure your wallet to connect to Anvil:");
        console.log("   - Network Name: Anvil Local");
        console.log("   - RPC URL: http://localhost:8545");
        console.log("   - Chain ID:", addresses.chainId);
        console.log("   - Currency Symbol: ETH");
        console.log("");
        console.log("2. Import Anvil test account:");
        console.log("   - Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        console.log("   - Address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
        console.log("   - This account has 10,000 ETH for testing");
        console.log("");
        console.log("3. Add token contracts to wallet:");
        console.log("   - DSC Token:", addresses.dsc);
        console.log("   - WETH Token:", addresses.weth);
        console.log("   - WBTC Token:", addresses.wbtc);
        console.log("");
        console.log("4. Get ABIs from: ./out/[ContractName].sol/[ContractName].json");
        console.log("   - DSC ABI: ./out/DecentralizedStableCoin.sol/DecentralizedStableCoin.json");
        console.log("   - DSCEngine ABI: ./out/DSCEngine.sol/DSCEngine.json");
        console.log("   - ERC20 ABI: ./out/ERC20Mock.sol/ERC20Mock.json");
    }

    /**
     * @notice Get ABI file paths for frontend
     */
    function getAbiPaths() external pure {
        console.log("=== ABI File Paths ===");
        console.log("DSC ABI: ./out/DecentralizedStableCoin.sol/DecentralizedStableCoin.json");
        console.log("DSCEngine ABI: ./out/DSCEngine.sol/DSCEngine.json");
        console.log("ERC20Mock ABI: ./out/ERC20Mock.sol/ERC20Mock.json");
        console.log("MockV3Aggregator ABI: ./out/MockV3Aggregator.sol/MockV3Aggregator.json");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title HelperConfig
 * @notice Network configuration helper for DSC deployment
 * @dev Provides network-specific configurations for mainnet and testnet deployments
 */
contract HelperConfig is Script {
    // Network configuration structure
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    // Constants for mock deployments
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 50000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    // Network configurations
    NetworkConfig public activeNetworkConfig;

    // Mock contracts for local testing
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    ERC20Mock public wethMock;
    ERC20Mock public wbtcMock;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /**
     * @notice Get Ethereum mainnet configuration
     * @return NetworkConfig for Ethereum mainnet
     */
    function getMainnetEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH/USD
            wbtcUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC/USD
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    /**
     * @notice Get Sepolia testnet configuration
     * @return NetworkConfig for Sepolia testnet
     */
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH/USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, // BTC/USD
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, // Sepolia WETH
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, // Sepolia WBTC (mock)
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    /**
     * @notice Get or create Anvil local configuration with mocks
     * @return NetworkConfig for local Anvil network
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check if we already have an active config to avoid redeployment
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        // Deploy mock price feeds
        vm.startBroadcast();
        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        // Deploy mock ERC20 tokens
        wethMock = new ERC20Mock();
        wbtcMock = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }

    /**
     * @notice Get the active network configuration
     * @return NetworkConfig for the current network
     */
    function getConfig() external view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    /**
     * @notice Get network name for logging purposes
     * @return string Network name
     */
    function getNetworkName() external view returns (string memory) {
        if (block.chainid == 1) {
            return "mainnet";
        } else if (block.chainid == 11155111) {
            return "sepolia";
        } else if (block.chainid == 31337) {
            return "anvil";
        } else {
            return "unknown";
        }
    }

    /**
     * @notice Check if current network is a testnet
     * @return bool True if testnet, false if mainnet
     */
    function isTestnet() external view returns (bool) {
        return block.chainid != 1;
    }

    /**
     * @notice Get collateral token addresses as arrays
     * @return tokenAddresses Array of collateral token addresses
     * @return priceFeedAddresses Array of corresponding price feed addresses
     */
    function getCollateralTokensAndPriceFeeds()
        external
        view
        returns (address[] memory tokenAddresses, address[] memory priceFeedAddresses)
    {
        tokenAddresses = new address[](2);
        priceFeedAddresses = new address[](2);

        tokenAddresses[0] = activeNetworkConfig.weth;
        tokenAddresses[1] = activeNetworkConfig.wbtc;
        priceFeedAddresses[0] = activeNetworkConfig.wethUsdPriceFeed;
        priceFeedAddresses[1] = activeNetworkConfig.wbtcUsdPriceFeed;

        return (tokenAddresses, priceFeedAddresses);
    }
}

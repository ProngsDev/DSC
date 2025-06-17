// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

/**
 * @title UpdatePrices
 * @notice Script for updating mock price feeds in local testing
 * @dev Only works on local Anvil network with mock price feeds
 */
contract UpdatePrices is Script {
    /**
     * @notice Update ETH price to simulate market conditions
     * @param newPrice New ETH price in USD (with 8 decimals)
     */
    function updateEthPrice(int256 newPrice) external {
        require(block.chainid == 31337, "Only available on local Anvil");

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        console.log("Updating ETH/USD price feed...");
        console.log("Old price: $", uint256(MockV3Aggregator(config.wethUsdPriceFeed).latestAnswer()) / 1e8);
        console.log("New price: $", uint256(newPrice) / 1e8);

        vm.broadcast();
        MockV3Aggregator(config.wethUsdPriceFeed).updateAnswer(newPrice);

        console.log("ETH price updated successfully!");
    }

    /**
     * @notice Update BTC price to simulate market conditions
     * @param newPrice New BTC price in USD (with 8 decimals)
     */
    function updateBtcPrice(int256 newPrice) external {
        require(block.chainid == 31337, "Only available on local Anvil");

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        console.log("Updating BTC/USD price feed...");
        console.log("Old price: $", uint256(MockV3Aggregator(config.wbtcUsdPriceFeed).latestAnswer()) / 1e8);
        console.log("New price: $", uint256(newPrice) / 1e8);

        vm.broadcast();
        MockV3Aggregator(config.wbtcUsdPriceFeed).updateAnswer(newPrice);

        console.log("BTC price updated successfully!");
    }

    /**
     * @notice Update both ETH and BTC prices
     * @param newEthPrice New ETH price in USD (with 8 decimals)
     * @param newBtcPrice New BTC price in USD (with 8 decimals)
     */
    function updateBothPrices(int256 newEthPrice, int256 newBtcPrice) external {
        require(block.chainid == 31337, "Only available on local Anvil");

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        console.log("Updating both price feeds...");

        vm.startBroadcast();
        MockV3Aggregator(config.wethUsdPriceFeed).updateAnswer(newEthPrice);
        MockV3Aggregator(config.wbtcUsdPriceFeed).updateAnswer(newBtcPrice);
        vm.stopBroadcast();

        console.log("ETH price updated to: $", uint256(newEthPrice) / 1e8);
        console.log("BTC price updated to: $", uint256(newBtcPrice) / 1e8);
    }

    /**
     * @notice Simulate a market crash (50% price drop)
     */
    function simulateMarketCrash() external {
        require(block.chainid == 31337, "Only available on local Anvil");

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Get current prices
        int256 currentEthPrice = MockV3Aggregator(config.wethUsdPriceFeed).latestAnswer();
        int256 currentBtcPrice = MockV3Aggregator(config.wbtcUsdPriceFeed).latestAnswer();

        // Calculate 50% drop
        int256 newEthPrice = currentEthPrice / 2;
        int256 newBtcPrice = currentBtcPrice / 2;

        console.log("*** SIMULATING MARKET CRASH (50% drop) ***");
        console.log("ETH: $", uint256(currentEthPrice) / 1e8, "-> $", uint256(newEthPrice) / 1e8);
        console.log("BTC: $", uint256(currentBtcPrice) / 1e8, "-> $", uint256(newBtcPrice) / 1e8);

        vm.startBroadcast();
        MockV3Aggregator(config.wethUsdPriceFeed).updateAnswer(newEthPrice);
        MockV3Aggregator(config.wbtcUsdPriceFeed).updateAnswer(newBtcPrice);
        vm.stopBroadcast();

        console.log("Market crash simulated! Check for liquidatable positions.");
    }

    /**
     * @notice Get current prices from mock feeds
     */
    function getCurrentPrices() external {
        require(block.chainid == 31337, "Only available on local Anvil");

        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        int256 ethPrice = MockV3Aggregator(config.wethUsdPriceFeed).latestAnswer();
        int256 btcPrice = MockV3Aggregator(config.wbtcUsdPriceFeed).latestAnswer();

        console.log("=== Current Mock Price Feed Values ===");
        console.log("ETH/USD: $", uint256(ethPrice) / 1e8);
        console.log("BTC/USD: $", uint256(btcPrice) / 1e8);
        console.log("ETH Price Feed:", config.wethUsdPriceFeed);
        console.log("BTC Price Feed:", config.wbtcUsdPriceFeed);
    }
}

/**
 * @title UpdateEthPrice
 * @notice Standalone script for updating ETH price
 */
contract UpdateEthPrice is Script {
    function run() external {
        // Example: Set ETH to $1500
        UpdatePrices updater = new UpdatePrices();
        updater.updateEthPrice(1500e8);
    }
}

/**
 * @title UpdateBtcPrice
 * @notice Standalone script for updating BTC price
 */
contract UpdateBtcPrice is Script {
    function run() external {
        // Example: Set BTC to $40000
        UpdatePrices updater = new UpdatePrices();
        updater.updateBtcPrice(40000e8);
    }
}

/**
 * @title SimulateMarketCrash
 * @notice Standalone script for simulating market crash
 */
contract SimulateMarketCrash is Script {
    function run() external {
        UpdatePrices updater = new UpdatePrices();
        updater.simulateMarketCrash();
    }
}

/**
 * @title GetCurrentPrices
 * @notice Standalone script for checking current prices
 */
contract GetCurrentPrices is Script {
    function run() external {
        UpdatePrices updater = new UpdatePrices();
        updater.getCurrentPrices();
    }
}

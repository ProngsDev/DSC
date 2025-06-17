// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

/**
 * @title DeploymentTest
 * @notice Test suite for deployment scripts
 * @dev Ensures deployment scripts work correctly across different networks
 */
contract DeploymentTest is Test {
    DeployDSC deployer;
    HelperConfig helperConfig;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;

    function setUp() public {
        deployer = new DeployDSC();
    }

    /**
     * @notice Test deployment on local Anvil network
     */
    function testDeploymentOnAnvil() public {
        // Deploy the system
        (dsc, dscEngine, helperConfig) = deployer.run();

        // Verify deployment
        _verifyDeployment();

        console.log("Anvil deployment test passed");
    }

    /**
     * @notice Test network configuration helper
     */
    function testHelperConfigNetworkDetection() public {
        helperConfig = new HelperConfig();

        // Should detect Anvil (chain ID 31337)
        assertEq(vm.toString(block.chainid), "31337");

        string memory networkName = helperConfig.getNetworkName();
        assertEq(networkName, "anvil");

        assertTrue(helperConfig.isTestnet());

        console.log("Network detection test passed");
    }

    /**
     * @notice Test collateral token configuration
     */
    function testCollateralTokenConfiguration() public {
        helperConfig = new HelperConfig();

        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();

        // Should have 2 collateral tokens (WETH and WBTC)
        assertEq(tokenAddresses.length, 2);
        assertEq(priceFeedAddresses.length, 2);

        // Addresses should not be zero
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            assertTrue(tokenAddresses[i] != address(0));
            assertTrue(priceFeedAddresses[i] != address(0));
        }

        console.log("Collateral configuration test passed");
    }

    /**
     * @notice Test deployment validation
     */
    function testDeploymentValidation() public {
        (dsc, dscEngine, helperConfig) = deployer.run();

        // Test DSC contract
        assertEq(dsc.name(), "DecentralizedStableCoin");
        assertEq(dsc.symbol(), "DSC");
        assertEq(dsc.owner(), address(dscEngine));

        // Test DSCEngine contract
        assertTrue(address(dscEngine) != address(0));

        // Test price feed mappings
        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            assertEq(dscEngine.priceFeeds(tokenAddresses[i]), priceFeedAddresses[i]);
        }

        console.log("Deployment validation test passed");
    }

    /**
     * @notice Test deployment summary generation
     */
    function testDeploymentSummary() public {
        (dsc, dscEngine, helperConfig) = deployer.run();

        string memory summary =
            deployer.getDeploymentSummary(address(dsc), address(dscEngine), helperConfig.getNetworkName());

        // Summary should contain key information
        assertTrue(bytes(summary).length > 0);

        console.log("Deployment Summary:");
        console.log(summary);
        console.log("Deployment summary test passed");
    }

    /**
     * @notice Internal function to verify deployment integrity
     */
    function _verifyDeployment() internal view {
        // Verify contracts are deployed
        assertTrue(address(dsc) != address(0), "DSC not deployed");
        assertTrue(address(dscEngine) != address(0), "DSCEngine not deployed");
        assertTrue(address(helperConfig) != address(0), "HelperConfig not deployed");

        // Verify DSC configuration
        assertEq(dsc.name(), "DecentralizedStableCoin", "DSC name incorrect");
        assertEq(dsc.symbol(), "DSC", "DSC symbol incorrect");
        assertEq(dsc.owner(), address(dscEngine), "DSC ownership not transferred");

        // Verify DSCEngine configuration
        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            assertEq(dscEngine.priceFeeds(tokenAddresses[i]), priceFeedAddresses[i], "Price feed mapping incorrect");
        }
    }
}

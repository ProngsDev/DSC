// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title Interactions
 * @notice Post-deployment interaction scripts for DSC system
 * @dev Provides scripts for testing and interacting with deployed contracts
 */
contract Interactions is Script {
    // Interaction configuration
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant DSC_AMOUNT_TO_MINT = 5000e18; // 5000 DSC

    /**
     * @notice Deposit collateral to the most recently deployed DSCEngine
     */
    function depositCollateral() external {
        HelperConfig helperConfig = new HelperConfig();
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);
        address wethAddress = helperConfig.getConfig().weth;

        _depositCollateral(dscEngineAddress, wethAddress, COLLATERAL_AMOUNT);
    }

    /**
     * @notice Mint DSC tokens using the most recently deployed contracts
     */
    function mintDsc() external {
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);
        _mintDsc(dscEngineAddress, DSC_AMOUNT_TO_MINT);
    }

    /**
     * @notice Deposit collateral and mint DSC in one transaction
     */
    function depositAndMint() external {
        HelperConfig helperConfig = new HelperConfig();
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);
        address wethAddress = helperConfig.getConfig().weth;

        _depositCollateral(dscEngineAddress, wethAddress, COLLATERAL_AMOUNT);
        _mintDsc(dscEngineAddress, DSC_AMOUNT_TO_MINT);
    }

    /**
     * @notice Get system status for the deployed contracts
     */
    function getSystemStatus() external {
        HelperConfig helperConfig = new HelperConfig();
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);
        address dscAddress = DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid);

        _logSystemStatus(dscEngineAddress, dscAddress, helperConfig);
    }

    /**
     * @notice Fund user with collateral tokens for testing (testnet only)
     */
    function fundUserWithCollateral(address user, uint256 amount) external {
        HelperConfig helperConfig = new HelperConfig();
        require(helperConfig.isTestnet(), "Only available on testnets");

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.deployerKey);

        // For local/testnet, mint tokens to user
        if (block.chainid == 31337) {
            // Anvil
            IERC20(config.weth).transfer(user, amount);
            IERC20(config.wbtc).transfer(user, amount);
        }

        vm.stopBroadcast();

        console.log("Funded user with tokens");
        console.log("User:", user);
        console.log("Amount:", amount);
    }

    /**
     * @notice Internal function to deposit collateral
     * @param dscEngineAddress Address of the DSCEngine contract
     * @param tokenAddress Address of the collateral token
     * @param amount Amount to deposit
     */
    function _depositCollateral(address dscEngineAddress, address tokenAddress, uint256 amount) internal {
        console.log("=== Depositing Collateral ===");
        console.log("DSCEngine:", dscEngineAddress);
        console.log("Token:", tokenAddress);
        console.log("Amount:", amount);

        vm.startBroadcast();

        // Approve DSCEngine to spend tokens
        IERC20(tokenAddress).approve(dscEngineAddress, amount);

        // Deposit collateral
        DSCEngine(dscEngineAddress).depositCollateral(tokenAddress, amount);

        vm.stopBroadcast();

        console.log("Collateral deposited successfully");
    }

    /**
     * @notice Internal function to mint DSC
     * @param dscEngineAddress Address of the DSCEngine contract
     * @param amount Amount of DSC to mint
     */
    function _mintDsc(address dscEngineAddress, uint256 amount) internal {
        console.log("=== Minting DSC ===");
        console.log("DSCEngine:", dscEngineAddress);
        console.log("Amount:", amount);

        vm.startBroadcast();
        DSCEngine(dscEngineAddress).mintDSC(amount);
        vm.stopBroadcast();

        console.log("DSC minted successfully");
    }

    /**
     * @notice Internal function to log system status
     * @param dscEngineAddress Address of the DSCEngine contract
     * @param dscAddress Address of the DSC contract
     * @param helperConfig HelperConfig instance
     */
    function _logSystemStatus(address dscEngineAddress, address dscAddress, HelperConfig helperConfig) internal view {
        console.log("=== System Status ===");
        console.log("Network:", helperConfig.getNetworkName());
        console.log("Chain ID:", block.chainid);
        console.log("DSC Address:", dscAddress);
        console.log("DSCEngine Address:", dscEngineAddress);

        DecentralizedStableCoin dsc = DecentralizedStableCoin(dscAddress);
        console.log("DSC Total Supply:", dsc.totalSupply());
        console.log("DSC Owner:", dsc.owner());

        // Get collateral tokens
        (address[] memory tokens,) = helperConfig.getCollateralTokensAndPriceFeeds();
        console.log("Supported Collateral Tokens:");
        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("  Token", i, ":", tokens[i]);
        }
    }
}

/**
 * @title DepositCollateral
 * @notice Standalone script for depositing collateral
 */
contract DepositCollateral is Script {
    function run() external {
        Interactions interactions = new Interactions();
        interactions.depositCollateral();
    }
}

/**
 * @title MintDsc
 * @notice Standalone script for minting DSC
 */
contract MintDsc is Script {
    function run() external {
        Interactions interactions = new Interactions();
        interactions.mintDsc();
    }
}

/**
 * @title DepositAndMint
 * @notice Standalone script for depositing collateral and minting DSC
 */
contract DepositAndMint is Script {
    function run() external {
        Interactions interactions = new Interactions();
        interactions.depositAndMint();
    }
}

/**
 * @title GetSystemStatus
 * @notice Standalone script for getting system status
 */
contract GetSystemStatus is Script {
    function run() external {
        Interactions interactions = new Interactions();
        interactions.getSystemStatus();
    }
}

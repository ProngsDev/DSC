// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployDSC
 * @notice Main deployment script for the Decentralized Stablecoin system
 * @dev Deploys DSC token, DSCEngine, and configures the system properly
 */
contract DeployDSC is Script {
    // Deployment configuration
    struct DeploymentConfig {
        address[] tokenAddresses;
        address[] priceFeedAddresses;
        uint256 deployerKey;
    }

    // Events for deployment tracking
    event DSCDeployed(address indexed dscAddress, address indexed deployer);
    event DSCEngineDeployed(address indexed dscEngineAddress, address indexed dscAddress, address indexed deployer);
    event OwnershipTransferred(address indexed dscAddress, address indexed newOwner);
    event DeploymentCompleted(
        address indexed dscAddress, address indexed dscEngineAddress, address indexed deployer, string network
    );

    /**
     * @notice Main deployment function
     * @return dsc The deployed DecentralizedStableCoin contract
     * @return dscEngine The deployed DSCEngine contract
     * @return helperConfig The HelperConfig contract with network configurations
     */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        // Get network configuration
        HelperConfig helperConfig = new HelperConfig();
        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();
        uint256 deployerKey = helperConfig.getConfig().deployerKey;

        // Log deployment information
        console.log("=== DSC Deployment Started ===");
        console.log("Network:", helperConfig.getNetworkName());
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", vm.addr(deployerKey));
        console.log("WETH Address:", tokenAddresses[0]);
        console.log("WBTC Address:", tokenAddresses[1]);
        console.log("ETH/USD Price Feed:", priceFeedAddresses[0]);
        console.log("BTC/USD Price Feed:", priceFeedAddresses[1]);

        // Perform pre-deployment validations
        _validateDeploymentConfig(tokenAddresses, priceFeedAddresses);

        // Deploy contracts
        vm.startBroadcast(deployerKey);

        // 1. Deploy DecentralizedStableCoin
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        emit DSCDeployed(address(dsc), vm.addr(deployerKey));
        console.log("DSC deployed at:", address(dsc));

        // 2. Deploy DSCEngine
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        emit DSCEngineDeployed(address(dscEngine), address(dsc), vm.addr(deployerKey));
        console.log("DSCEngine deployed at:", address(dscEngine));

        // 3. Transfer DSC ownership to DSCEngine
        dsc.transferOwnership(address(dscEngine));
        emit OwnershipTransferred(address(dsc), address(dscEngine));
        console.log("DSC ownership transferred to DSCEngine");

        vm.stopBroadcast();

        // Perform post-deployment validations
        _validateDeployment(dsc, dscEngine, tokenAddresses, priceFeedAddresses);

        // Log completion
        emit DeploymentCompleted(address(dsc), address(dscEngine), vm.addr(deployerKey), helperConfig.getNetworkName());
        console.log("=== DSC Deployment Completed Successfully ===");

        return (dsc, dscEngine, helperConfig);
    }

    /**
     * @notice Validate deployment configuration before deployment
     * @param tokenAddresses Array of collateral token addresses
     * @param priceFeedAddresses Array of price feed addresses
     */
    function _validateDeploymentConfig(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        internal
        pure
    {
        console.log("=== Pre-deployment Validation ===");

        // Check array lengths match
        require(tokenAddresses.length == priceFeedAddresses.length, "Token and price feed arrays length mismatch");
        require(tokenAddresses.length > 0, "No collateral tokens configured");

        // Check for zero addresses
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            require(tokenAddresses[i] != address(0), "Token address cannot be zero");
            require(priceFeedAddresses[i] != address(0), "Price feed address cannot be zero");
        }

        console.log("Pre-deployment validation passed");
    }

    /**
     * @notice Validate deployment after contracts are deployed
     * @param dsc The deployed DSC contract
     * @param dscEngine The deployed DSCEngine contract
     * @param tokenAddresses Array of collateral token addresses
     * @param priceFeedAddresses Array of price feed addresses
     */
    function _validateDeployment(
        DecentralizedStableCoin dsc,
        DSCEngine dscEngine,
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses
    ) internal view {
        console.log("=== Post-deployment Validation ===");

        // Validate DSC contract
        require(address(dsc) != address(0), "DSC deployment failed");
        require(keccak256(bytes(dsc.name())) == keccak256(bytes("DecentralizedStableCoin")), "DSC name incorrect");
        require(keccak256(bytes(dsc.symbol())) == keccak256(bytes("DSC")), "DSC symbol incorrect");
        require(dsc.owner() == address(dscEngine), "DSC ownership not transferred correctly");

        // Validate DSCEngine contract
        require(address(dscEngine) != address(0), "DSCEngine deployment failed");

        // Validate collateral tokens configuration
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            require(dscEngine.priceFeeds(tokenAddresses[i]) == priceFeedAddresses[i], "Price feed mapping incorrect");
        }

        console.log("Post-deployment validation passed");
    }

    /**
     * @notice Get deployment summary for external tools
     * @return summary Deployment summary string
     */
    function getDeploymentSummary(address dscAddress, address dscEngineAddress, string memory networkName)
        external
        pure
        returns (string memory summary)
    {
        return string(
            abi.encodePacked(
                "DSC System deployed on ",
                networkName,
                "\nDSC: ",
                _addressToString(dscAddress),
                "\nDSCEngine: ",
                _addressToString(dscEngineAddress)
            )
        );
    }

    /**
     * @notice Convert address to string for logging
     * @param addr Address to convert
     * @return String representation of address
     */
    function _addressToString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}

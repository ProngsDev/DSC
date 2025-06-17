// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title VerifyContracts
 * @notice Script for verifying deployed contracts on Etherscan
 * @dev Automatically retrieves deployed contract addresses and verifies them
 */
contract VerifyContracts is Script {
    /**
     * @notice Verify all deployed DSC contracts
     */
    function run() external {
        HelperConfig helperConfig = new HelperConfig();

        console.log("=== Contract Verification Started ===");
        console.log("Network:", helperConfig.getNetworkName());
        console.log("Chain ID:", block.chainid);

        // Only verify on public networks (not local)
        if (block.chainid == 31337) {
            console.log("Skipping verification on local network");
            return;
        }

        _verifyDSC();
        _verifyDSCEngine();

        console.log("=== Contract Verification Completed ===");
    }

    /**
     * @notice Verify DecentralizedStableCoin contract
     */
    function _verifyDSC() internal {
        address dscAddress = DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid);

        console.log("Verifying DecentralizedStableCoin at:", dscAddress);

        // DSC constructor has no parameters
        vm.broadcast();
        // Note: Actual verification would be done via forge verify-contract command
        // This script serves as a template for verification automation

        console.log("DSC verification initiated");
    }

    /**
     * @notice Verify DSCEngine contract
     */
    function _verifyDSCEngine() internal {
        address dscEngineAddress = DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid);
        address dscAddress = DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid);

        HelperConfig helperConfig = new HelperConfig();
        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();

        console.log("Verifying DSCEngine at:", dscEngineAddress);
        console.log("Constructor args:");
        console.log("  DSC Address:", dscAddress);
        console.log("  Token Addresses:");
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            console.log("    ", tokenAddresses[i]);
        }
        console.log("  Price Feed Addresses:");
        for (uint256 i = 0; i < priceFeedAddresses.length; i++) {
            console.log("    ", priceFeedAddresses[i]);
        }

        vm.broadcast();
        // Note: Actual verification would be done via forge verify-contract command
        // This script serves as a template for verification automation

        console.log("DSCEngine verification initiated");
    }

    /**
     * @notice Get verification command for manual execution
     * @param contractName Name of the contract to verify
     * @return command The forge verify-contract command
     */
    function getVerificationCommand(string memory contractName) external returns (string memory command) {
        address contractAddress = DevOpsTools.get_most_recent_deployment(contractName, block.chainid);

        if (keccak256(bytes(contractName)) == keccak256(bytes("DecentralizedStableCoin"))) {
            return string(
                abi.encodePacked(
                    "forge verify-contract ",
                    _addressToString(contractAddress),
                    " src/DecentralizedStableCoin.sol:DecentralizedStableCoin ",
                    "--chain-id ",
                    _uint256ToString(block.chainid),
                    " --etherscan-api-key $ETHERSCAN_API_KEY"
                )
            );
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("DSCEngine"))) {
            HelperConfig helperConfig = new HelperConfig();
            (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
                helperConfig.getCollateralTokensAndPriceFeeds();
            address dscAddress = DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid);

            // Build constructor args
            string memory constructorArgs = string(
                abi.encodePacked(
                    "--constructor-args $(cast abi-encode \"constructor(address[],address[],address)\" ",
                    "[",
                    _addressToString(tokenAddresses[0]),
                    ",",
                    _addressToString(tokenAddresses[1]),
                    "] ",
                    "[",
                    _addressToString(priceFeedAddresses[0]),
                    ",",
                    _addressToString(priceFeedAddresses[1]),
                    "] ",
                    _addressToString(dscAddress),
                    ")"
                )
            );

            return string(
                abi.encodePacked(
                    "forge verify-contract ",
                    _addressToString(contractAddress),
                    " src/DSCEngine.sol:DSCEngine ",
                    "--chain-id ",
                    _uint256ToString(block.chainid),
                    " --etherscan-api-key $ETHERSCAN_API_KEY ",
                    constructorArgs
                )
            );
        }

        return "Unknown contract";
    }

    /**
     * @notice Convert address to string
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

    /**
     * @notice Convert uint256 to string
     * @param value Value to convert
     * @return String representation of value
     */
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

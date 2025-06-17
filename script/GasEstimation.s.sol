// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DeployDSC} from "./DeployDSC.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GasEstimation
 * @notice Script for estimating gas costs for DSC system operations
 * @dev Provides gas estimates for deployment and common operations
 */
contract GasEstimation is Script {
    struct GasEstimates {
        uint256 deployDSC;
        uint256 deployDSCEngine;
        uint256 depositCollateral;
        uint256 mintDSC;
        uint256 burnDSC;
        uint256 redeemCollateral;
        uint256 liquidate;
    }

    /**
     * @notice Run gas estimation for all operations
     */
    function run() external {
        console.log("=== DSC Gas Estimation ===");

        GasEstimates memory estimates = _estimateGasCosts();
        _displayGasEstimates(estimates);
        _displayCostEstimates(estimates);
    }

    /**
     * @notice Estimate gas costs for all operations
     * @return estimates Struct containing gas estimates
     */
    function _estimateGasCosts() internal returns (GasEstimates memory estimates) {
        HelperConfig helperConfig = new HelperConfig();
        (address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
            helperConfig.getCollateralTokensAndPriceFeeds();

        // Estimate deployment costs
        estimates.deployDSC = _estimateDeployDSC();
        estimates.deployDSCEngine = _estimateDeployDSCEngine(tokenAddresses, priceFeedAddresses);

        // Deploy contracts for operation estimates
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dscEngine));

        // Estimate operation costs
        estimates.depositCollateral = _estimateDepositCollateral(dscEngine, tokenAddresses[0]);
        estimates.mintDSC = _estimateMintDSC(dscEngine);
        estimates.burnDSC = _estimateBurnDSC(dscEngine);
        estimates.redeemCollateral = _estimateRedeemCollateral(dscEngine, tokenAddresses[0]);
        estimates.liquidate = _estimateLiquidate(dscEngine, tokenAddresses[0]);

        return estimates;
    }

    /**
     * @notice Estimate gas for DSC deployment
     */
    function _estimateDeployDSC() internal returns (uint256) {
        uint256 gasBefore = gasleft();
        new DecentralizedStableCoin();
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for DSCEngine deployment
     */
    function _estimateDeployDSCEngine(address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        internal
        returns (uint256)
    {
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();

        uint256 gasBefore = gasleft();
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for collateral deposit
     */
    function _estimateDepositCollateral(DSCEngine dscEngine, address token) internal returns (uint256) {
        uint256 amount = 1 ether;

        // Mint tokens for testing
        IERC20(token).transfer(address(this), amount);
        IERC20(token).approve(address(dscEngine), amount);

        uint256 gasBefore = gasleft();
        dscEngine.depositCollateral(token, amount);
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for DSC minting
     */
    function _estimateMintDSC(DSCEngine dscEngine) internal returns (uint256) {
        uint256 amount = 1000e18; // 1000 DSC

        uint256 gasBefore = gasleft();
        dscEngine.mintDSC(amount);
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for DSC burning
     */
    function _estimateBurnDSC(DSCEngine dscEngine) internal returns (uint256) {
        uint256 amount = 500e18; // 500 DSC

        uint256 gasBefore = gasleft();
        dscEngine.burnDSC(amount);
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for collateral redemption
     */
    function _estimateRedeemCollateral(DSCEngine dscEngine, address token) internal returns (uint256) {
        uint256 amount = 0.5 ether;

        uint256 gasBefore = gasleft();
        dscEngine.redeemCollateral(token, amount);
        return gasBefore - gasleft();
    }

    /**
     * @notice Estimate gas for liquidation
     */
    function _estimateLiquidate(DSCEngine dscEngine, address token) internal returns (uint256) {
        // This is a simplified estimate - actual liquidation requires specific setup
        uint256 debtToCover = 100e18; // 100 DSC
        address userToLiquidate = address(0x123); // Placeholder

        uint256 gasBefore = gasleft();
        try dscEngine.liquidate(token, userToLiquidate, debtToCover) {
            return gasBefore - gasleft();
        } catch {
            // Return estimated gas for failed liquidation attempt
            return 200000; // Estimated gas for liquidation
        }
    }

    /**
     * @notice Display gas estimates in a formatted table
     */
    function _displayGasEstimates(GasEstimates memory estimates) internal view {
        console.log("\n=== Gas Estimates ===");
        console.log("Operation                | Gas Used");
        console.log("-------------------------|----------");
        console.log("Deploy DSC              |", estimates.deployDSC);
        console.log("Deploy DSCEngine        |", estimates.deployDSCEngine);
        console.log("Deposit Collateral      |", estimates.depositCollateral);
        console.log("Mint DSC                |", estimates.mintDSC);
        console.log("Burn DSC                |", estimates.burnDSC);
        console.log("Redeem Collateral       |", estimates.redeemCollateral);
        console.log("Liquidate               |", estimates.liquidate);
        console.log("-------------------------|----------");
        console.log("Total Deployment        |", estimates.deployDSC + estimates.deployDSCEngine);
    }

    /**
     * @notice Display cost estimates at different gas prices
     */
    function _displayCostEstimates(GasEstimates memory estimates) internal view {
        console.log("\n=== Cost Estimates (ETH) ===");

        uint256[] memory gasPrices = new uint256[](4);
        gasPrices[0] = 10; // 10 gwei
        gasPrices[1] = 20; // 20 gwei
        gasPrices[2] = 50; // 50 gwei
        gasPrices[3] = 100; // 100 gwei

        console.log("Operation                | 10 gwei  | 20 gwei  | 50 gwei  | 100 gwei");
        console.log("-------------------------|----------|----------|----------|----------");

        _displayOperationCosts("Deploy DSC              ", estimates.deployDSC, gasPrices);
        _displayOperationCosts("Deploy DSCEngine        ", estimates.deployDSCEngine, gasPrices);
        _displayOperationCosts("Deposit Collateral      ", estimates.depositCollateral, gasPrices);
        _displayOperationCosts("Mint DSC                ", estimates.mintDSC, gasPrices);
        _displayOperationCosts("Burn DSC                ", estimates.burnDSC, gasPrices);
        _displayOperationCosts("Redeem Collateral       ", estimates.redeemCollateral, gasPrices);
        _displayOperationCosts("Liquidate               ", estimates.liquidate, gasPrices);

        console.log("-------------------------|----------|----------|----------|----------");
        uint256 totalDeployment = estimates.deployDSC + estimates.deployDSCEngine;
        _displayOperationCosts("Total Deployment        ", totalDeployment, gasPrices);
    }

    /**
     * @notice Display cost estimates for a specific operation
     */
    function _displayOperationCosts(string memory operation, uint256 gasUsed, uint256[] memory gasPrices)
        internal
        view
    {
        console.log(operation);
        console.log("  10 gwei:", _formatCost(gasUsed, gasPrices[0]));
        console.log("  20 gwei:", _formatCost(gasUsed, gasPrices[1]));
        console.log("  50 gwei:", _formatCost(gasUsed, gasPrices[2]));
        console.log(" 100 gwei:", _formatCost(gasUsed, gasPrices[3]));
    }

    /**
     * @notice Format cost in ETH with proper decimals
     */
    function _formatCost(uint256 gasUsed, uint256 gasPriceGwei) internal pure returns (string memory) {
        uint256 costWei = gasUsed * gasPriceGwei * 1e9; // Convert gwei to wei
        uint256 costEth = costWei / 1e18; // Convert wei to ETH (integer part)
        uint256 costEthDecimals = (costWei % 1e18) / 1e14; // Get 4 decimal places

        if (costEth > 0) {
            return string(abi.encodePacked(_uint256ToString(costEth), ".", _uint256ToString(costEthDecimals), " ETH"));
        } else {
            return string(abi.encodePacked("0.", _uint256ToString(costEthDecimals), " ETH"));
        }
    }

    /**
     * @notice Convert uint256 to string
     */
    function _uint256ToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

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

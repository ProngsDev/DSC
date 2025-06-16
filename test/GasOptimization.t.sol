// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

/**
 * @title GasOptimizationTest
 * @notice Test suite to measure and validate gas optimizations
 * @dev Demonstrates gas efficiency improvements in the DSC protocol
 */
contract GasOptimizationTest is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    MockV3Aggregator ethUsdPriceFeed;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant DSC_AMOUNT = 1000e18;

    address public user = makeAddr("user");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        weth = new ERC20Mock();
        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        tokenAddresses = [address(weth)];
        priceFeedAddresses = [address(ethUsdPriceFeed)];

        dsc = new DecentralizedStableCoin();
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dsce));

        // Setup user with collateral
        weth.mint(user, COLLATERAL_AMOUNT * 2);
        weth.mint(liquidator, COLLATERAL_AMOUNT);
    }

    /// @notice Test gas usage for deposit collateral operation
    /// @dev Measures gas consumption for optimized collateral deposit
    function testGasOptimizedDepositCollateral() public {
        vm.startPrank(user);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);

        uint256 gasBefore = gasleft();
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for depositCollateral:", gasUsed);
        
        // Verify functionality still works
        assertEq(dsce.userCollateralBalance(user, address(weth)), COLLATERAL_AMOUNT);
        vm.stopPrank();

        // Gas usage should be reasonable (under 100k for simple deposit)
        assertLt(gasUsed, 100000, "Deposit collateral gas usage too high");
    }

    /// @notice Test gas usage for mint DSC operation
    /// @dev Measures gas consumption for optimized DSC minting
    function testGasOptimizedMintDSC() public {
        // Setup: Deposit collateral first
        vm.startPrank(user);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);

        uint256 gasBefore = gasleft();
        dsce.mintDSC(DSC_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for mintDSC:", gasUsed);
        
        // Verify functionality
        assertEq(dsc.balanceOf(user), DSC_AMOUNT);
        assertEq(dsce.userMintedDsc(user), DSC_AMOUNT);
        vm.stopPrank();

        // Gas usage should be reasonable (under 150k for mint with health factor check)
        assertLt(gasUsed, 150000, "Mint DSC gas usage too high");
    }

    /// @notice Test gas usage for burn DSC operation
    /// @dev Measures gas consumption for optimized DSC burning
    function testGasOptimizedBurnDSC() public {
        // Setup: Deposit collateral and mint DSC
        vm.startPrank(user);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        dsce.mintDSC(DSC_AMOUNT);

        dsc.approve(address(dsce), DSC_AMOUNT);
        uint256 gasBefore = gasleft();
        dsce.burnDSC(DSC_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for burnDSC:", gasUsed);
        
        // Verify functionality
        assertEq(dsc.balanceOf(user), 0);
        assertEq(dsce.userMintedDsc(user), 0);
        vm.stopPrank();

        // Gas usage should be reasonable (under 100k for burn)
        assertLt(gasUsed, 100000, "Burn DSC gas usage too high");
    }

    /// @notice Test gas usage for liquidation operation
    /// @dev Measures gas consumption for optimized liquidation
    function testGasOptimizedLiquidation() public {
        // Setup: User with undercollateralized position
        vm.startPrank(user);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        dsce.mintDSC(DSC_AMOUNT * 5); // High leverage
        vm.stopPrank();

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        dsce.mintDSC(DSC_AMOUNT);
        vm.stopPrank();

        // Crash price to make position liquidatable
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 3);

        vm.startPrank(liquidator);
        dsc.approve(address(dsce), DSC_AMOUNT);
        
        uint256 gasBefore = gasleft();
        dsce.liquidate(address(weth), user, DSC_AMOUNT);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for liquidation:", gasUsed);
        vm.stopPrank();

        // Gas usage should be reasonable (under 200k for liquidation)
        assertLt(gasUsed, 200000, "Liquidation gas usage too high");
    }

    /// @notice Test gas usage for health factor calculation
    /// @dev Measures gas consumption for optimized health factor calculation
    function testGasOptimizedHealthFactor() public {
        // Setup: User with collateral and debt
        vm.startPrank(user);
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        dsce.mintDSC(DSC_AMOUNT);
        vm.stopPrank();

        uint256 gasBefore = gasleft();
        uint256 healthFactor = dsce.getHealthFactor(user);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for getHealthFactor:", gasUsed);
        console.log("Health factor:", healthFactor);
        
        // Health factor should be reasonable (> 1e18 for healthy position)
        assertGt(healthFactor, 1e18);
        
        // Gas usage should be very low for view function (under 50k)
        assertLt(gasUsed, 50000, "Health factor calculation gas usage too high");
    }

    /// @notice Test gas usage comparison for multiple operations
    /// @dev Demonstrates cumulative gas savings across operations
    function testGasOptimizedWorkflow() public {
        uint256 totalGasUsed = 0;
        uint256 gasBefore;
        uint256 gasUsed;

        vm.startPrank(user);
        
        // 1. Approve and deposit collateral
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        gasBefore = gasleft();
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        gasUsed = gasBefore - gasleft();
        totalGasUsed += gasUsed;
        console.log("Step 1 - Deposit gas:", gasUsed);

        // 2. Mint DSC
        gasBefore = gasleft();
        dsce.mintDSC(DSC_AMOUNT);
        gasUsed = gasBefore - gasleft();
        totalGasUsed += gasUsed;
        console.log("Step 2 - Mint gas:", gasUsed);

        // 3. Check health factor
        gasBefore = gasleft();
        dsce.getHealthFactor(user);
        gasUsed = gasBefore - gasleft();
        totalGasUsed += gasUsed;
        console.log("Step 3 - Health factor gas:", gasUsed);

        // 4. Burn some DSC
        dsc.approve(address(dsce), DSC_AMOUNT / 2);
        gasBefore = gasleft();
        dsce.burnDSC(DSC_AMOUNT / 2);
        gasUsed = gasBefore - gasleft();
        totalGasUsed += gasUsed;
        console.log("Step 4 - Burn gas:", gasUsed);

        vm.stopPrank();

        console.log("Total gas used for workflow:", totalGasUsed);
        
        // Total workflow should be efficient (under 400k gas)
        assertLt(totalGasUsed, 400000, "Total workflow gas usage too high");
    }

    /// @notice Test that optimizations don't break functionality
    /// @dev Ensures gas optimizations maintain correctness
    function testOptimizationsPreserveFunctionality() public {
        vm.startPrank(user);
        
        // Test full workflow functionality
        weth.approve(address(dsce), COLLATERAL_AMOUNT);
        dsce.depositCollateral(address(weth), COLLATERAL_AMOUNT);
        
        uint256 initialBalance = dsce.userCollateralBalance(user, address(weth));
        assertEq(initialBalance, COLLATERAL_AMOUNT);
        
        dsce.mintDSC(DSC_AMOUNT);
        assertEq(dsc.balanceOf(user), DSC_AMOUNT);
        assertEq(dsce.userMintedDsc(user), DSC_AMOUNT);
        
        uint256 healthFactor = dsce.getHealthFactor(user);
        assertGt(healthFactor, 1e18, "Position should be healthy");
        
        dsc.approve(address(dsce), DSC_AMOUNT);
        dsce.burnDSC(DSC_AMOUNT);
        assertEq(dsc.balanceOf(user), 0);
        assertEq(dsce.userMintedDsc(user), 0);
        
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20MockWithDecimals} from "./mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

/**
 * @title IntegrationTests
 * @notice Integration tests for complete DSC protocol workflows
 * @dev Tests end-to-end scenarios and multi-step operations
 */
contract IntegrationTests is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20MockWithDecimals wbtc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 50000e8;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        weth = new ERC20Mock();
        wbtc = new ERC20MockWithDecimals("Wrapped Bitcoin", "WBTC", 8);
        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        tokenAddresses = [address(weth), address(wbtc)];
        priceFeedAddresses = [address(ethUsdPriceFeed), address(btcUsdPriceFeed)];

        dsc = new DecentralizedStableCoin();
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dsce));

        // Mint tokens to users
        weth.mint(alice, 100 ether);
        wbtc.mint(alice, 10e8);
        weth.mint(bob, 100 ether);
        wbtc.mint(bob, 10e8);
        weth.mint(charlie, 100 ether);
        wbtc.mint(charlie, 10e8);
        weth.mint(liquidator, 100 ether);
        wbtc.mint(liquidator, 10e8);
    }

    /// @notice Test complete user lifecycle: deposit, mint, burn, redeem
    function testCompleteUserLifecycle() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(alice);

        // 1. Deposit collateral
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        assertEq(dsce.userCollateralBalance(alice, address(weth)), collateralAmount);
        assertEq(weth.balanceOf(address(dsce)), collateralAmount);

        // 2. Mint DSC
        dsce.mintDSC(mintAmount);

        assertEq(dsc.balanceOf(alice), mintAmount);
        assertEq(dsce.userMintedDsc(alice), mintAmount);

        uint256 healthFactor = dsce.getHealthFactor(alice);
        assertGt(healthFactor, 1e18, "Health factor should be > 1");

        // 3. Burn some DSC
        uint256 burnAmount = mintAmount / 2;
        dsc.approve(address(dsce), burnAmount);
        dsce.burnDSC(burnAmount);

        assertEq(dsc.balanceOf(alice), mintAmount - burnAmount);
        assertEq(dsce.userMintedDsc(alice), mintAmount - burnAmount);

        // 4. Redeem some collateral
        uint256 redeemAmount = collateralAmount / 4;
        dsce.redeemCollateral(address(weth), redeemAmount);

        assertEq(dsce.userCollateralBalance(alice, address(weth)), collateralAmount - redeemAmount);

        // 5. Burn remaining DSC
        uint256 remainingDebt = dsce.userMintedDsc(alice);
        dsc.approve(address(dsce), remainingDebt);
        dsce.burnDSC(remainingDebt);

        assertEq(dsc.balanceOf(alice), 0);
        assertEq(dsce.userMintedDsc(alice), 0);

        // 6. Redeem remaining collateral
        uint256 remainingCollateral = dsce.userCollateralBalance(alice, address(weth));
        dsce.redeemCollateral(address(weth), remainingCollateral);

        assertEq(dsce.userCollateralBalance(alice, address(weth)), 0);

        vm.stopPrank();
    }

    /// @notice Test multi-user system with different collateral types
    function testMultiUserMultiCollateralSystem() public {
        // Alice uses ETH collateral - ultra conservative
        // 10 ETH * $2000 = $20,000 collateral
        // Max safe mint at 150% = $20,000 * 100/150 = $13,333
        vm.startPrank(alice);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(8000e18); // Very conservative
        vm.stopPrank();

        // Bob uses BTC collateral - ultra conservative
        // 1 BTC * $50,000 = $50,000 collateral
        // Max safe mint at 150% = $50,000 * 100/150 = $33,333
        vm.startPrank(bob);
        wbtc.approve(address(dsce), 1e8); // 1 BTC
        dsce.depositCollateral(address(wbtc), 1e8);
        dsce.mintDSC(15000e18); // Extra conservative due to precision
        vm.stopPrank();

        // Charlie uses both collaterals - ultra conservative
        // 5 ETH * $2000 + 0.5 BTC * $50,000 = $10,000 + $25,000 = $35,000
        // Max safe mint at 150% = $35,000 * 100/150 = $23,333
        vm.startPrank(charlie);
        weth.approve(address(dsce), 5 ether);
        wbtc.approve(address(dsce), 0.5e8);
        dsce.depositCollateral(address(weth), 5 ether);
        dsce.depositCollateral(address(wbtc), 0.5e8);
        dsce.mintDSC(12000e18); // Extra conservative due to precision
        vm.stopPrank();

        // Verify independent positions
        assertEq(dsc.balanceOf(alice), 8000e18);
        assertEq(dsc.balanceOf(bob), 15000e18);
        assertEq(dsc.balanceOf(charlie), 12000e18);

        // Verify total DSC supply
        assertEq(dsc.totalSupply(), 35000e18);

        // Verify all positions are healthy
        assertGt(dsce.getHealthFactor(alice), 1e18);
        assertGt(dsce.getHealthFactor(bob), 1e18);
        assertGt(dsce.getHealthFactor(charlie), 1e18);
    }

    /// @notice Test liquidation cascade scenario
    function testLiquidationCascade() public {
        // Setup multiple users with leveraged positions
        vm.startPrank(alice);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(12000e18); // High leverage
        vm.stopPrank();

        vm.startPrank(bob);
        weth.approve(address(dsce), 8 ether);
        dsce.depositCollateral(address(weth), 8 ether);
        dsce.mintDSC(9000e18); // High leverage
        vm.stopPrank();

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 20 ether);
        dsce.depositCollateral(address(weth), 20 ether);
        dsce.mintDSC(15000e18);
        vm.stopPrank();

        // Crash ETH price by 60%
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE * 40 / 100);

        // Both Alice and Bob should be liquidatable
        assertLt(dsce.getHealthFactor(alice), 1e18);
        assertLt(dsce.getHealthFactor(bob), 1e18);

        // Liquidate Alice
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 12000e18);
        dsce.liquidate(address(weth), alice, 6000e18); // Partial liquidation
        vm.stopPrank();

        // Liquidate Bob
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 9000e18);
        dsce.liquidate(address(weth), bob, 4500e18); // Partial liquidation
        vm.stopPrank();

        // Verify liquidations occurred
        assertLt(dsce.userMintedDsc(alice), 12000e18);
        assertLt(dsce.userMintedDsc(bob), 9000e18);

        // Liquidator should have gained collateral
        assertGt(dsce.userCollateralBalance(liquidator, address(weth)), 20 ether);
    }

    /// @notice Test system behavior during extreme market volatility
    function testExtremeMarketVolatility() public {
        // Setup initial positions
        vm.startPrank(alice);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(8000e18);
        vm.stopPrank();

        vm.startPrank(liquidator);
        weth.approve(address(dsce), 20 ether);
        dsce.depositCollateral(address(weth), 20 ether);
        dsce.mintDSC(10000e18);
        vm.stopPrank();

        uint256 initialHealthFactor = dsce.getHealthFactor(alice);
        assertGt(initialHealthFactor, 1e18);

        // Simulate extreme price volatility
        int256[] memory prices = new int256[](5);
        prices[0] = ETH_USD_PRICE / 2; // 50% drop
        prices[1] = ETH_USD_PRICE * 3 / 4; // Recovery to 75%
        prices[2] = ETH_USD_PRICE / 3; // Crash to 33%
        prices[3] = ETH_USD_PRICE; // Full recovery
        prices[4] = ETH_USD_PRICE * 2; // 100% gain

        for (uint256 i = 0; i < prices.length; i++) {
            ethUsdPriceFeed.updateAnswer(prices[i]);

            uint256 healthFactor = dsce.getHealthFactor(alice);

            if (healthFactor < 1e18) {
                // Position is liquidatable
                vm.startPrank(liquidator);
                uint256 debtToCover = dsce.userMintedDsc(alice) / 4; // Partial liquidation
                if (dsc.balanceOf(liquidator) >= debtToCover) {
                    dsc.approve(address(dsce), debtToCover);
                    dsce.liquidate(address(weth), alice, debtToCover);
                }
                vm.stopPrank();
            }
        }

        // System should remain stable throughout volatility
        assertTrue(dsc.totalSupply() > 0, "DSC should still exist");
        assertTrue(weth.balanceOf(address(dsce)) > 0, "Collateral should remain in system");
    }

    /// @notice Test protocol behavior with multiple liquidators
    function testMultipleLiquidators() public {
        address liquidator2 = makeAddr("liquidator2");
        weth.mint(liquidator2, 100 ether);

        // Setup user with leveraged position
        // 50 ETH * $2000 = $100,000 collateral
        // Max safe mint at 150% = $100,000 * 100/150 = $66,666
        vm.startPrank(alice);
        weth.approve(address(dsce), 50 ether);
        dsce.depositCollateral(address(weth), 50 ether);
        dsce.mintDSC(50000e18); // Conservative leverage
        vm.stopPrank();

        // Setup liquidators with enough DSC to liquidate
        // 30 ETH * $2000 = $60,000 collateral each
        // Max safe mint at 150% = $60,000 * 100/150 = $40,000 each
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 30 ether);
        dsce.depositCollateral(address(weth), 30 ether);
        dsce.mintDSC(35000e18);
        vm.stopPrank();

        vm.startPrank(liquidator2);
        weth.approve(address(dsce), 30 ether);
        dsce.depositCollateral(address(weth), 30 ether);
        dsce.mintDSC(35000e18);
        vm.stopPrank();

        // Crash price
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 3);

        assertLt(dsce.getHealthFactor(alice), 1e18);

        uint256 aliceDebtBefore = dsce.userMintedDsc(alice);

        // Both liquidators compete to liquidate
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 25000e18);
        dsce.liquidate(address(weth), alice, 25000e18);
        vm.stopPrank();

        vm.startPrank(liquidator2);
        uint256 remainingDebt = dsce.userMintedDsc(alice);
        if (remainingDebt > 0) {
            dsc.approve(address(dsce), remainingDebt);
            dsce.liquidate(address(weth), alice, remainingDebt);
        }
        vm.stopPrank();

        // Alice's debt should be significantly reduced or eliminated
        assertLt(dsce.userMintedDsc(alice), aliceDebtBefore);

        // Both liquidators should have gained collateral
        assertGt(dsce.userCollateralBalance(liquidator, address(weth)), 30 ether);
        assertGt(dsce.userCollateralBalance(liquidator2, address(weth)), 30 ether);
    }

    /// @notice Test system recovery after major liquidation event
    function testSystemRecoveryAfterLiquidation() public {
        // Setup multiple users
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;

        // Each user deposits and mints
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            weth.approve(address(dsce), 10 ether);
            dsce.depositCollateral(address(weth), 10 ether);
            dsce.mintDSC(8000e18);
            vm.stopPrank();
        }

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 50 ether);
        dsce.depositCollateral(address(weth), 50 ether);
        dsce.mintDSC(30000e18);
        vm.stopPrank();

        uint256 totalSupplyBefore = dsc.totalSupply();

        // Major price crash
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 4);

        // Liquidate all users
        vm.startPrank(liquidator);
        for (uint256 i = 0; i < users.length; i++) {
            if (dsce.getHealthFactor(users[i]) < 1e18) {
                uint256 userDebt = dsce.userMintedDsc(users[i]);
                dsc.approve(address(dsce), userDebt);
                dsce.liquidate(address(weth), users[i], userDebt);
            }
        }
        vm.stopPrank();

        uint256 totalSupplyAfter = dsc.totalSupply();

        // Total supply should decrease due to debt burning
        assertLt(totalSupplyAfter, totalSupplyBefore);

        // Price recovery
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE);

        // New users should be able to use the system normally
        address newUser = makeAddr("newUser");
        weth.mint(newUser, 20 ether);

        vm.startPrank(newUser);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(5000e18);

        assertEq(dsc.balanceOf(newUser), 5000e18);
        assertGt(dsce.getHealthFactor(newUser), 1e18);
        vm.stopPrank();
    }

    /// @notice Test cross-collateral liquidation scenarios
    function testCrossCollateralLiquidation() public {
        // Alice deposits both ETH and BTC - conservative amounts
        // 5 ETH * $2000 + 0.5 BTC * $50,000 = $10,000 + $25,000 = $35,000
        // Max safe mint at 150% = $35,000 * 100/150 = $23,333
        vm.startPrank(alice);
        weth.approve(address(dsce), 5 ether);
        wbtc.approve(address(dsce), 0.5e8);
        dsce.depositCollateral(address(weth), 5 ether);
        dsce.depositCollateral(address(wbtc), 0.5e8);
        dsce.mintDSC(15000e18); // Higher leverage to make liquidatable when ETH crashes
        vm.stopPrank();

        // Setup liquidator
        // 10 ETH * $2000 = $20,000 collateral
        // Max safe mint at 150% = $20,000 * 100/150 = $13,333
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(10000e18); // Conservative amount
        vm.stopPrank();

        // Crash both ETH and BTC prices to make position liquidatable
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 10); // 90% price drop
        btcUsdPriceFeed.updateAnswer(BTC_USD_PRICE / 10); // 90% price drop

        assertLt(dsce.getHealthFactor(alice), 1e18);

        // Liquidator can choose which collateral to seize
        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 10000e18);

        // Liquidate ETH collateral (partial)
        dsce.liquidate(address(weth), alice, 5000e18);

        // Liquidate BTC collateral (partial)
        dsce.liquidate(address(wbtc), alice, 5000e18);
        vm.stopPrank();

        // Alice should have reduced debt and collateral
        assertLt(dsce.userMintedDsc(alice), 15000e18);
        assertLt(dsce.userCollateralBalance(alice, address(weth)), 5 ether);
        assertLt(dsce.userCollateralBalance(alice, address(wbtc)), 0.5e8);
    }
}

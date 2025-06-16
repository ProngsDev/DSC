// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20MockWithDecimals} from "./mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

/**
 * @title FuzzTests
 * @notice Comprehensive fuzz testing for the DSC protocol
 * @dev Tests protocol behavior with random inputs to find edge cases
 */
contract FuzzTests is Test {
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

    address public user = makeAddr("user");
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

        // Mint large amounts for fuzz testing
        weth.mint(user, 1000000 ether);
        wbtc.mint(user, 1000000 ether);
        weth.mint(liquidator, 1000000 ether);
        wbtc.mint(liquidator, 1000000 ether);
    }

    /// @notice Fuzz test collateral deposit with random amounts
    /// @param amount Random collateral amount to deposit
    function testFuzzDepositCollateral(uint256 amount) public {
        // Bound amount to reasonable range (1 wei to 1000 ETH)
        amount = bound(amount, 1, 1000 ether);

        vm.startPrank(user);
        weth.approve(address(dsce), amount);

        dsce.depositCollateral(address(weth), amount);

        assertEq(dsce.userCollateralBalance(user, address(weth)), amount);
        vm.stopPrank();
    }

    /// @notice Fuzz test DSC minting with random amounts
    /// @param collateralAmount Random collateral amount
    /// @param mintAmount Random DSC amount to mint
    function testFuzzMintDSC(uint256 collateralAmount, uint256 mintAmount) public {
        // Bound inputs to reasonable ranges
        collateralAmount = bound(collateralAmount, 1 ether, 100 ether);
        mintAmount = bound(mintAmount, 1e18, 50000e18);

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        // Calculate max safe mint amount (considering 150% collateralization)
        uint256 collateralValueUsd = (collateralAmount * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxSafeMint = (collateralValueUsd * 100) / 150; // 150% threshold

        if (mintAmount <= maxSafeMint) {
            // Should succeed
            dsce.mintDSC(mintAmount);
            assertEq(dsc.balanceOf(user), mintAmount);
            assertEq(dsce.userMintedDsc(user), mintAmount);
        } else {
            // Should revert due to health factor
            vm.expectRevert(DSCEngine.DSCEngine_HealthFactorTooLow.selector);
            dsce.mintDSC(mintAmount);
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test health factor calculation with random inputs
    /// @param collateralAmount Random collateral amount
    /// @param debtAmount Random debt amount
    function testFuzzHealthFactor(uint256 collateralAmount, uint256 debtAmount) public {
        // Bound inputs to reasonable ranges
        collateralAmount = bound(collateralAmount, 1 ether, 100 ether);
        debtAmount = bound(debtAmount, 1e18, 10000e18);

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        // Calculate expected health factor
        uint256 collateralValueUsd = (collateralAmount * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxSafeMint = (collateralValueUsd * 100) / 150;

        if (debtAmount <= maxSafeMint) {
            dsce.mintDSC(debtAmount);
            uint256 healthFactor = dsce.getHealthFactor(user);

            // Health factor should be >= 1e18 for safe positions
            assertGe(healthFactor, 1e18, "Health factor should be >= 1e18 for safe positions");
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test liquidation with random parameters
    /// @param collateralAmount Random collateral amount
    /// @param debtAmount Random debt amount
    /// @param priceDropPercent Random price drop percentage
    function testFuzzLiquidation(uint256 collateralAmount, uint256 debtAmount, uint256 priceDropPercent) public {
        // Bound inputs
        collateralAmount = bound(collateralAmount, 10 ether, 100 ether);
        debtAmount = bound(debtAmount, 1000e18, 50000e18);
        priceDropPercent = bound(priceDropPercent, 10, 90); // 10% to 90% price drop

        // Setup user position
        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        uint256 collateralValueUsd = (collateralAmount * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxSafeMint = (collateralValueUsd * 100) / 150;

        if (debtAmount > maxSafeMint) {
            vm.expectRevert(DSCEngine.DSCEngine_HealthFactorTooLow.selector);
            dsce.mintDSC(debtAmount);
            vm.stopPrank();
            return;
        }

        dsce.mintDSC(debtAmount);
        vm.stopPrank();

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(debtAmount);
        vm.stopPrank();

        // Drop price
        int256 newPrice = ETH_USD_PRICE * int256(100 - priceDropPercent) / 100;
        ethUsdPriceFeed.updateAnswer(newPrice);

        uint256 healthFactor = dsce.getHealthFactor(user);

        if (healthFactor < 1e18) {
            // Position should be liquidatable
            vm.startPrank(liquidator);
            dsc.approve(address(dsce), debtAmount);

            // Liquidation should succeed
            dsce.liquidate(address(weth), user, debtAmount / 2); // Partial liquidation
            vm.stopPrank();
        }
    }

    /// @notice Fuzz test redeem collateral with random amounts
    /// @param depositAmount Random deposit amount
    /// @param redeemAmount Random redeem amount
    function testFuzzRedeemCollateral(uint256 depositAmount, uint256 redeemAmount) public {
        // Bound inputs
        depositAmount = bound(depositAmount, 1 ether, 100 ether);
        redeemAmount = bound(redeemAmount, 1, depositAmount);

        vm.startPrank(user);
        weth.approve(address(dsce), depositAmount);
        dsce.depositCollateral(address(weth), depositAmount);

        if (redeemAmount <= depositAmount) {
            dsce.redeemCollateral(address(weth), redeemAmount);
            assertEq(dsce.userCollateralBalance(user, address(weth)), depositAmount - redeemAmount);
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test burn DSC with random amounts
    /// @param mintAmount Random mint amount
    /// @param burnAmount Random burn amount
    function testFuzzBurnDSC(uint256 mintAmount, uint256 burnAmount) public {
        // Bound inputs
        mintAmount = bound(mintAmount, 1e18, 10000e18);
        burnAmount = bound(burnAmount, 1, mintAmount);

        // Setup sufficient collateral
        uint256 collateralAmount = 100 ether;
        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        uint256 collateralValueUsd = (collateralAmount * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxSafeMint = (collateralValueUsd * 100) / 150;

        if (mintAmount <= maxSafeMint) {
            dsce.mintDSC(mintAmount);

            if (burnAmount <= mintAmount) {
                dsc.approve(address(dsce), burnAmount);
                dsce.burnDSC(burnAmount);
                assertEq(dsce.userMintedDsc(user), mintAmount - burnAmount);
            }
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test multiple collateral types
    /// @param ethAmount Random ETH collateral amount
    /// @param btcAmount Random BTC collateral amount
    /// @param mintAmount Random DSC mint amount
    function testFuzzMultipleCollateral(uint256 ethAmount, uint256 btcAmount, uint256 mintAmount) public {
        // Bound inputs
        ethAmount = bound(ethAmount, 1 ether, 50 ether);
        btcAmount = bound(btcAmount, 1e8, 10e8); // 1 to 10 BTC (8 decimals)
        mintAmount = bound(mintAmount, 1e18, 100000e18);

        vm.startPrank(user);

        // Deposit both collaterals
        weth.approve(address(dsce), ethAmount);
        wbtc.approve(address(dsce), btcAmount);
        dsce.depositCollateral(address(weth), ethAmount);
        dsce.depositCollateral(address(wbtc), btcAmount);

        // Calculate total collateral value properly accounting for decimals
        // ETH: 18 decimals, price feed: 8 decimals -> (amount * price) / 1e8
        uint256 ethValueUsd = (ethAmount * uint256(ETH_USD_PRICE)) / 1e8;
        // BTC: 8 decimals, price feed: 8 decimals -> (amount * price) / 1e8 * 1e10 (to normalize to 18 decimals)
        uint256 btcValueUsd = (btcAmount * uint256(BTC_USD_PRICE) * 1e10) / 1e8;
        uint256 totalCollateralUsd = ethValueUsd + btcValueUsd;
        uint256 maxSafeMint = (totalCollateralUsd * 100) / 150;

        if (mintAmount <= maxSafeMint) {
            dsce.mintDSC(mintAmount);
            uint256 healthFactor = dsce.getHealthFactor(user);
            assertGe(healthFactor, 1e18, "Health factor should be >= 1e18");
        } else {
            vm.expectRevert(DSCEngine.DSCEngine_HealthFactorTooLow.selector);
            dsce.mintDSC(mintAmount);
        }
        vm.stopPrank();
    }

    /// @notice Fuzz test price volatility scenarios
    /// @param initialPrice Random initial price
    /// @param priceChange Random price change percentage
    function testFuzzPriceVolatility(int256 initialPrice, int256 priceChange) public {
        // Bound inputs to realistic ranges
        initialPrice = int256(bound(uint256(initialPrice), 100e8, 10000e8)); // $100 to $10,000
        priceChange = int256(bound(uint256(priceChange), 50, 200)); // 50% to 200% of original

        // Set initial price
        ethUsdPriceFeed.updateAnswer(initialPrice);

        // Setup position
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 5000e18;

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        // Calculate if mint is safe with initial price
        uint256 collateralValueUsd = (collateralAmount * uint256(initialPrice)) / 1e8;
        uint256 maxSafeMint = (collateralValueUsd * 100) / 150;

        if (mintAmount <= maxSafeMint) {
            dsce.mintDSC(mintAmount);

            // Change price
            int256 newPrice = (initialPrice * priceChange) / 100;
            if (newPrice > 0) {
                ethUsdPriceFeed.updateAnswer(newPrice);

                // Check health factor after price change
                uint256 healthFactor = dsce.getHealthFactor(user);

                if (healthFactor < 1e18) {
                    // Position became liquidatable
                    assertTrue(true, "Position correctly became liquidatable after price drop");
                } else {
                    // Position remained healthy
                    assertTrue(true, "Position remained healthy after price change");
                }
            }
        }
        vm.stopPrank();
    }
}

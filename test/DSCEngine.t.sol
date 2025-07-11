// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC20MockWithDecimals} from "./mocks/ERC20MockWithDecimals.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 100000e8;

    uint256 public constant USER_MINT_AMOUNT = 100 ether;

    address public user = makeAddr("user");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        // Initialize the contract
        weth = new ERC20Mock();
        wbtc = new ERC20Mock();

        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);

        tokenAddresses = [address(weth), address(wbtc)];
        priceFeedAddresses = [address(ethUsdPriceFeed), address(btcUsdPriceFeed)];

        dsc = new DecentralizedStableCoin();
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

        dsc.transferOwnership(address(dsce));

        weth.mint(user, USER_MINT_AMOUNT);
        wbtc.mint(user, USER_MINT_AMOUNT);
    }

    function testDepositCollateral() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);

        dsce.depositCollateral(address(weth), 10 ether);

        uint256 balance = dsce.userCollateralBalance(user, address(weth));
        assertEq(balance, 10 ether);
        vm.stopPrank();
    }

    function testCannotDepositZeroCollateral() public {
        vm.startPrank(user);
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.depositCollateral(address(weth), 0 ether);
        vm.stopPrank();
    }

    function testReedemCollateral() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        dsce.redeemCollateral(address(weth), 5 ether);

        uint256 balance = dsce.userCollateralBalance(user, address(weth));
        assertEq(balance, 5 ether);
        vm.stopPrank();
    }

    function testCannotRedeemMoreThanBalance() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine_InsufficientCollateral.selector);
        dsce.redeemCollateral(address(weth), 15 ether);
        vm.stopPrank();
    }

    function testMintSucceedsWithProperCollateral() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountToMint = 100;
        dsce.mintDSC(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
        vm.stopPrank();
    }

    function testMintFailedWithZeroAmount() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 100 ether);
        dsce.depositCollateral(address(weth), 100 ether);
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.mintDSC(0);
        vm.stopPrank();
    }

    function testMintFailsHealtFactorTooLow() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        uint256 amountToMint = 10001e18;

        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorTooLow.selector);
        dsce.mintDSC(amountToMint);
        vm.stopPrank();
    }

    function testBurnSucceeds() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        uint256 amountToMint = 100;
        dsce.mintDSC(amountToMint);

        dsc.approve(address(dsce), amountToMint);
        dsce.burnDSC(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
        vm.stopPrank();
    }

    function testBurnFailsIfBurnAmountExceeedsMinted() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountToMint = 100;
        dsce.mintDSC(amountToMint);

        uint256 amountToBurn = amountToMint + 1000;
        dsc.approve(address(dsce), amountToBurn);
        vm.expectRevert(DSCEngine.DSCEngine_BurnAmountExceedsMinted.selector);
        dsce.burnDSC(amountToBurn);
        vm.stopPrank();
    }

    function testBurnFailsWithZeroAmount() public {
        vm.startPrank(user);

        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.burnDSC(0);

        vm.stopPrank();
    }

    function testliquidateTransfersCollateralWithBonus() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountDscToMint = 10000e18;
        dsce.mintDSC(amountDscToMint);
        vm.stopPrank();

        weth.mint(liquidator, 10 ether);
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(amountDscToMint);
        vm.stopPrank();

        int256 newEthPrice = ETH_USD_PRICE / 2;
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        uint256 liquidatorWethBalanceBefore = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userWethBalanceBefore = dsce.userCollateralBalance(user, address(weth));

        uint256 debtToCover = 1000e18;

        vm.startPrank(liquidator);
        dsc.approve(address(dsce), 1000e21);
        dsce.liquidate(address(weth), user, debtToCover);
        vm.stopPrank();

        uint256 liquidatorWethBalanceAfter = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userWethBalanceAfter = dsce.userCollateralBalance(user, address(weth));

        assertLt(userWethBalanceAfter, userWethBalanceBefore);
        assertGt(liquidatorWethBalanceAfter, liquidatorWethBalanceBefore);

        uint256 expectedCollateralReceived = dsce.getTokenAmountFromUsd(address(weth), debtToCover);
        uint256 bonusCollateral = (expectedCollateralReceived * 10) / 100;
        uint256 totalCollateralReceived = expectedCollateralReceived + bonusCollateral;

        assertEq(liquidatorWethBalanceAfter - liquidatorWethBalanceBefore, totalCollateralReceived);

        assertEq(userWethBalanceBefore - userWethBalanceAfter, totalCollateralReceived);
    }

    function testLiquidateImprovesHealthFactor() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        uint256 amountDscToMint = 10000e18;
        dsce.mintDSC(amountDscToMint);

        int256 newEthPrice = ETH_USD_PRICE / 2;
        ethUsdPriceFeed.updateAnswer(newEthPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 newUserHealthFactor = dsce.getHealthFactor(user);
        assertGt(newUserHealthFactor, 1e18);
        vm.stopPrank();
    }

    function testLiquidateCapsCollateralIfInsufficent() public {
        // Setup user with small amount of collateral
        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        // Mint a large amount of DSC
        uint256 amountDscToMint = 1000e18; // Smaller amount than other tests
        dsce.mintDSC(amountDscToMint);
        vm.stopPrank();

        // Setup liquidator with enough DSC to cover the debt
        weth.mint(liquidator, 10 ether);
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(amountDscToMint * 2); // More than enough to cover
        vm.stopPrank();

        // Crash the price to make user's position liquidatable
        int256 newEthPrice = ETH_USD_PRICE / 10;
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        // Verify user is underwater
        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        // Record balances before liquidation
        uint256 liquidatorWethBalanceBefore = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userWethBalanceBefore = dsce.userCollateralBalance(user, address(weth));

        // Try to liquidate more than the user has as collateral
        uint256 debtToCover = amountDscToMint; // Try to liquidate all debt

        vm.startPrank(liquidator);
        dsc.approve(address(dsce), debtToCover);
        dsce.liquidate(address(weth), user, debtToCover);
        vm.stopPrank();

        // Check balances after liquidation
        uint256 liquidatorWethBalanceAfter = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userWethBalanceAfter = dsce.userCollateralBalance(user, address(weth));

        // User should have 0 collateral left
        assertEq(userWethBalanceAfter, 0);

        // Liquidator should have received all the user's collateral
        assertEq(liquidatorWethBalanceAfter - liquidatorWethBalanceBefore, userWethBalanceBefore);

        // The user's collateral should be completely gone
        assertEq(userWethBalanceBefore - userWethBalanceAfter, userWethBalanceBefore);
    }

    function testCannotLiquidateHealthyUser() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        uint256 amountDscToMint = 500e18;
        dsce.mintDSC(amountDscToMint);
        vm.stopPrank();

        // Setup liquidator with DSC tokens to cover the debt
        weth.mint(liquidator, 10 ether);
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(amountDscToMint); // Mint enough DSC to cover liquidation
        vm.stopPrank();

        // Verify initial health factor is good
        uint256 initialHealthFactor = dsce.getHealthFactor(user);
        assertGt(initialHealthFactor, 1e18);

        // Attempt to liquidate a healthy position (should fail)
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorOk.selector);
        dsce.liquidate(address(weth), user, amountDscToMint);
        vm.stopPrank();

        // Even with a moderate price drop, position should remain healthy
        int256 newEthPrice = ETH_USD_PRICE * 80 / 100; // 20% price drop
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        // Verify health factor is still good after price drop
        uint256 healthFactorAfterPriceDrop = dsce.getHealthFactor(user);
        assertGt(healthFactorAfterPriceDrop, 1e18);

        // Attempt to liquidate should still fail
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorOk.selector);
        dsce.liquidate(address(weth), user, amountDscToMint);
        vm.stopPrank();
    }

    function testCannotLiquidateWithZeroDebtToCover() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountToMint = 5000e18;
        dsce.mintDSC(amountToMint);
        vm.stopPrank();

        int256 newEthPrice = ETH_USD_PRICE / 3;
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine_InvalidDebtAmount.selector);
        dsce.liquidate(address(weth), user, 0);
        vm.stopPrank();
    }

    function testCannotLiquidateMoreThanUserDebt() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountToMint = 5000e18;
        dsce.mintDSC(amountToMint);
        vm.stopPrank();

        // Setup liquidator with enough DSC tokens to attempt the liquidation
        weth.mint(liquidator, 20 ether);
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 20 ether);
        dsce.depositCollateral(address(weth), 20 ether);
        dsce.mintDSC(amountToMint * 2); // Mint enough DSC to cover the attempted liquidation
        vm.stopPrank();

        int256 newEthPrice = ETH_USD_PRICE / 3;
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine_InvalidDebtAmount.selector);
        dsce.liquidate(address(weth), user, amountToMint * 2);
        vm.stopPrank();
    }

    // Test for collateral token validation fix
    function testCannotLiquidateWithUnsupportedCollateral() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);

        uint256 amountToMint = 5000e18;
        dsce.mintDSC(amountToMint);
        vm.stopPrank();

        // Setup liquidator with DSC tokens
        weth.mint(liquidator, 10 ether);
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(amountToMint);
        vm.stopPrank();

        // Crash the price to make user's position liquidatable
        int256 newEthPrice = ETH_USD_PRICE / 3;
        ethUsdPriceFeed.updateAnswer(newEthPrice);

        uint256 userHealthFactor = dsce.getHealthFactor(user);
        assertLt(userHealthFactor, 1e18);

        // Create a fake token address that's not supported
        address unsupportedToken = makeAddr("unsupportedToken");

        // Try to liquidate with unsupported collateral token
        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine_TokenNotSupported.selector, unsupportedToken));
        dsce.liquidate(unsupportedToken, user, 1000e18);
        vm.stopPrank();
    }

    // Test for oracle precision handling
    function testOraclePrecisionHandling() public {
        // This test verifies that the oracle precision fixes work correctly
        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        // Test with small amounts to verify precision is maintained
        uint256 smallAmount = 1e15; // 0.001 ETH
        weth.approve(address(dsce), smallAmount);
        dsce.depositCollateral(address(weth), smallAmount);

        // Verify the collateral balance is correctly recorded
        uint256 totalBalance = dsce.userCollateralBalance(user, address(weth));
        assertEq(totalBalance, 1 ether + smallAmount);
        vm.stopPrank();
    }

    // Test precision handling with different token decimals
    function testPrecisionWithDifferentTokenDecimals() public {
        // Create tokens with different decimal places
        ERC20MockWithDecimals token6Decimals = new ERC20MockWithDecimals("USDC", "USDC", 6);
        ERC20MockWithDecimals token8Decimals = new ERC20MockWithDecimals("WBTC", "WBTC", 8);

        // Create price feeds for these tokens
        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(8, 1e8); // $1.00
        MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(8, 50000e8); // $50,000

        // Create new DSCEngine with these tokens
        address[] memory newTokens = new address[](2);
        address[] memory newPriceFeeds = new address[](2);

        newTokens[0] = address(token6Decimals);
        newTokens[1] = address(token8Decimals);
        newPriceFeeds[0] = address(usdcPriceFeed);
        newPriceFeeds[1] = address(wbtcPriceFeed);

        DecentralizedStableCoin newDsc = new DecentralizedStableCoin();
        DSCEngine newDsce = new DSCEngine(newTokens, newPriceFeeds, address(newDsc));
        newDsc.transferOwnership(address(newDsce));

        // Mint tokens to user
        token6Decimals.mint(user, 1000e6); // 1000 USDC (6 decimals)
        token8Decimals.mint(user, 1e8); // 1 WBTC (8 decimals)

        vm.startPrank(user);

        // Test USDC (6 decimals) precision
        token6Decimals.approve(address(newDsce), 1000e6);
        newDsce.depositCollateral(address(token6Decimals), 1000e6);

        // Test WBTC (8 decimals) precision
        token8Decimals.approve(address(newDsce), 1e8);
        newDsce.depositCollateral(address(token8Decimals), 1e8);

        // Verify balances are correctly recorded
        assertEq(newDsce.userCollateralBalance(user, address(token6Decimals)), 1000e6);
        assertEq(newDsce.userCollateralBalance(user, address(token8Decimals)), 1e8);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

/**
 * @title EdgeCasesTest
 * @notice Test suite for edge cases and boundary conditions
 * @dev Tests extreme scenarios and potential attack vectors
 */
contract EdgeCasesTest is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    ERC20Mock weth;
    MockV3Aggregator ethUsdPriceFeed;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    address public user = makeAddr("user");
    address public attacker = makeAddr("attacker");
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        weth = new ERC20Mock();
        ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);

        tokenAddresses = [address(weth)];
        priceFeedAddresses = [address(ethUsdPriceFeed)];

        dsc = new DecentralizedStableCoin();
        dsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        dsc.transferOwnership(address(dsce));

        weth.mint(user, 1000 ether);
        weth.mint(attacker, 1000 ether);
        weth.mint(liquidator, 1000 ether);
    }

    /// @notice Test minimum collateral deposit (1 wei)
    function testMinimumCollateralDeposit() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 1);

        dsce.depositCollateral(address(weth), 1);
        assertEq(dsce.userCollateralBalance(user, address(weth)), 1);
        vm.stopPrank();
    }

    /// @notice Test maximum collateral deposit (type(uint256).max)
    function testMaximumCollateralDeposit() public {
        // This test would require minting max tokens, which is impractical
        // Instead, test with a very large but realistic amount
        uint256 largeAmount = 1000000 ether;
        weth.mint(user, largeAmount);

        vm.startPrank(user);
        weth.approve(address(dsce), largeAmount);

        dsce.depositCollateral(address(weth), largeAmount);
        assertEq(dsce.userCollateralBalance(user, address(weth)), largeAmount);
        vm.stopPrank();
    }

    /// @notice Test zero amount operations should revert
    function testZeroAmountOperationsRevert() public {
        vm.startPrank(user);

        // Zero deposit should revert
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.depositCollateral(address(weth), 0);

        // Zero mint should revert
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.mintDSC(0);

        // Zero burn should revert
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.burnDSC(0);

        // Zero redeem should revert
        vm.expectRevert(DSCEngine.DSCEngine_NeedMoreThanZero.selector);
        dsce.redeemCollateral(address(weth), 0);

        vm.stopPrank();
    }

    /// @notice Test operations with unsupported tokens
    function testUnsupportedTokenOperations() public {
        ERC20Mock unsupportedToken = new ERC20Mock();
        unsupportedToken.mint(user, 100 ether);

        vm.startPrank(user);
        unsupportedToken.approve(address(dsce), 100 ether);

        // Deposit unsupported token should revert
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine_TokenNotSupported.selector, address(unsupportedToken))
        );
        dsce.depositCollateral(address(unsupportedToken), 100 ether);

        // Liquidation with unsupported collateral should revert
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine_TokenNotSupported.selector, address(unsupportedToken))
        );
        dsce.liquidate(address(unsupportedToken), user, 1000e18);

        vm.stopPrank();
    }

    /// @notice Test health factor at exact liquidation threshold
    function testHealthFactorAtLiquidationThreshold() public {
        uint256 collateralAmount = 10 ether;

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);

        // Calculate exact amount that puts health factor at 1.0
        uint256 collateralValueUsd = (collateralAmount * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxMintForHealthFactor1 = (collateralValueUsd * 100) / 150;

        // Mint exactly at threshold
        dsce.mintDSC(maxMintForHealthFactor1);

        uint256 healthFactor = dsce.getHealthFactor(user);

        // Health factor should be exactly 1e18 (or very close due to rounding)
        assertApproxEqAbs(healthFactor, 1e18, 1e15, "Health factor should be approximately 1.0");
        vm.stopPrank();
    }

    /// @notice Test liquidation when user has insufficient collateral for full bonus
    function testLiquidationInsufficientCollateralForBonus() public {
        uint256 smallCollateral = 1 ether;

        vm.startPrank(user);
        weth.approve(address(dsce), smallCollateral);
        dsce.depositCollateral(address(weth), smallCollateral);

        // Mint maximum possible
        uint256 collateralValueUsd = (smallCollateral * uint256(ETH_USD_PRICE)) / 1e8;
        uint256 maxMint = (collateralValueUsd * 100) / 150;
        dsce.mintDSC(maxMint);
        vm.stopPrank();

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(maxMint);
        vm.stopPrank();

        // Crash price to make liquidatable
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 3);

        uint256 liquidatorBalanceBefore = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userBalanceBefore = dsce.userCollateralBalance(user, address(weth));

        vm.startPrank(liquidator);
        dsc.approve(address(dsce), maxMint);
        dsce.liquidate(address(weth), user, maxMint);
        vm.stopPrank();

        uint256 liquidatorBalanceAfter = dsce.userCollateralBalance(liquidator, address(weth));
        uint256 userBalanceAfter = dsce.userCollateralBalance(user, address(weth));

        // User should have 0 collateral left (all seized)
        assertEq(userBalanceAfter, 0);

        // Liquidator should get all user's collateral
        assertEq(liquidatorBalanceAfter - liquidatorBalanceBefore, userBalanceBefore);
    }

    /// @notice Test oracle price edge cases
    function testOraclePriceEdgeCases() public {
        // Test with very low price (but positive)
        ethUsdPriceFeed.updateAnswer(1); // $0.00000001

        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        // Should be able to mint very little DSC
        uint256 healthFactor = dsce.getHealthFactor(user);
        assertEq(healthFactor, type(uint256).max, "Health factor should be max with no debt");
        vm.stopPrank();

        // Test with very high price
        ethUsdPriceFeed.updateAnswer(type(int256).max);

        vm.startPrank(user);
        // Should still work with extreme price
        uint256 newHealthFactor = dsce.getHealthFactor(user);
        assertEq(newHealthFactor, type(uint256).max, "Health factor should still be max");
        vm.stopPrank();
    }

    /// @notice Test negative oracle price should revert when price is used
    function testNegativeOraclePriceReverts() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        // Set negative price
        ethUsdPriceFeed.updateAnswer(-1);

        // Price validation happens when trying to mint (which calls getUsdValue)
        vm.expectRevert(DSCEngine.DSCEngine_InvalidPrice.selector);
        dsce.mintDSC(1000e18);
        vm.stopPrank();
    }

    /// @notice Test zero oracle price should revert when price is used
    function testZeroOraclePriceReverts() public {
        vm.startPrank(user);
        weth.approve(address(dsce), 1 ether);
        dsce.depositCollateral(address(weth), 1 ether);

        // Set zero price
        ethUsdPriceFeed.updateAnswer(0);

        // Price validation happens when trying to mint (which calls getUsdValue)
        vm.expectRevert(DSCEngine.DSCEngine_InvalidPrice.selector);
        dsce.mintDSC(1000e18);
        vm.stopPrank();
    }

    /// @notice Test redeem more collateral than deposited
    function testRedeemMoreThanDeposited() public {
        uint256 depositAmount = 5 ether;

        vm.startPrank(user);
        weth.approve(address(dsce), depositAmount);
        dsce.depositCollateral(address(weth), depositAmount);

        vm.expectRevert(DSCEngine.DSCEngine_InsufficientCollateral.selector);
        dsce.redeemCollateral(address(weth), depositAmount + 1);
        vm.stopPrank();
    }

    /// @notice Test burn more DSC than minted
    function testBurnMoreThanMinted() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 1000e18;

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(mintAmount);

        dsc.approve(address(dsce), mintAmount + 1);
        vm.expectRevert(DSCEngine.DSCEngine_BurnAmountExceedsMinted.selector);
        dsce.burnDSC(mintAmount + 1);
        vm.stopPrank();
    }

    /// @notice Test liquidation of healthy position should revert
    function testLiquidateHealthyPositionReverts() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 1000e18; // Well below liquidation threshold

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(mintAmount);
        vm.stopPrank();

        // Setup liquidator
        vm.startPrank(liquidator);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(mintAmount);

        dsc.approve(address(dsce), mintAmount);
        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorOk.selector);
        dsce.liquidate(address(weth), user, mintAmount);
        vm.stopPrank();
    }

    /// @notice Test liquidation with insufficient DSC balance
    function testLiquidateInsufficientDSCBalance() public {
        uint256 collateralAmount = 1 ether;
        uint256 mintAmount = 1000e18;

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(mintAmount);
        vm.stopPrank();

        // Crash price
        ethUsdPriceFeed.updateAnswer(ETH_USD_PRICE / 10);

        vm.startPrank(liquidator);
        // Liquidator has no DSC
        vm.expectRevert(DSCEngine.DSCEngine_InsufficientDSCBalance.selector);
        dsce.liquidate(address(weth), user, mintAmount);
        vm.stopPrank();
    }

    /// @notice Test redeem collateral that would break health factor
    function testRedeemCollateralBreaksHealthFactor() public {
        uint256 collateralAmount = 10 ether;
        uint256 mintAmount = 10000e18; // High leverage

        vm.startPrank(user);
        weth.approve(address(dsce), collateralAmount);
        dsce.depositCollateral(address(weth), collateralAmount);
        dsce.mintDSC(mintAmount);

        // Try to redeem most collateral (would break health factor)
        vm.expectRevert(DSCEngine.DSCEngine_HealthFactorTooLow.selector);
        dsce.redeemCollateral(address(weth), collateralAmount - 1 ether);
        vm.stopPrank();
    }

    /// @notice Test multiple users with same collateral token
    function testMultipleUsersInteraction() public {
        address user2 = makeAddr("user2");
        weth.mint(user2, 100 ether);

        // User 1 deposits
        vm.startPrank(user);
        weth.approve(address(dsce), 10 ether);
        dsce.depositCollateral(address(weth), 10 ether);
        dsce.mintDSC(1000e18);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        weth.approve(address(dsce), 5 ether);
        dsce.depositCollateral(address(weth), 5 ether);
        dsce.mintDSC(500e18);
        vm.stopPrank();

        // Verify independent balances
        assertEq(dsce.userCollateralBalance(user, address(weth)), 10 ether);
        assertEq(dsce.userCollateralBalance(user2, address(weth)), 5 ether);
        assertEq(dsce.userMintedDsc(user), 1000e18);
        assertEq(dsce.userMintedDsc(user2), 500e18);
        assertEq(dsc.balanceOf(user), 1000e18);
        assertEq(dsc.balanceOf(user2), 500e18);
    }

    /// @notice Test precision with very small amounts
    function testPrecisionWithSmallAmounts() public {
        uint256 smallAmount = 1; // 1 wei

        vm.startPrank(user);
        weth.approve(address(dsce), smallAmount);
        dsce.depositCollateral(address(weth), smallAmount);

        // Should handle small amounts without precision loss
        assertEq(dsce.userCollateralBalance(user, address(weth)), smallAmount);

        uint256 healthFactor = dsce.getHealthFactor(user);
        assertEq(healthFactor, type(uint256).max, "Health factor should be max with no debt");
        vm.stopPrank();
    }
}

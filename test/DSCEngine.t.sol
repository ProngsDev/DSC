// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
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
}

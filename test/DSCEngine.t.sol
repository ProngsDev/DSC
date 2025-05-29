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
}

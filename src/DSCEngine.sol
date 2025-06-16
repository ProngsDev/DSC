// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./lib/OracleLib.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine is ReentrancyGuard {
    using OracleLib for AggregatorV3Interface;

    //errors
    error DSCEngine_TokenAddressAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_TokenNotSupported(address token);
    error DSCEngine_TransferFailed();
    error DSCEngine_InsufficientCollateral();
    error DSCEngine_InsufficentDSCBalance();
    error DSCEngine_RedeemFailed();
    error DSCEngine_HealthFactorTooLow();
    error DSCEngine_HealthFactorTooHigh();
    error DSCEngine_MintFailed();
    error DSCEngine_BurnAmountExceedsMinted();
    error DSCEngine_HealthFactorOk();
    error DSCEngine_InvalidDebtAmount();
    error DSCEngine_HealthFactorNotImproved();
    error DSCEngine_InvalidPrice();
    error DSCEngine_ZeroAddress();

    //events
    event DSCMinted(address indexed user, uint256 amount);
    event DSCBurned(address indexed user, uint256 amount);
    event CollateralDeposit(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 amount, address indexed receiver);
    event Liquidation(address indexed liquidator, address indexed user, address indexed token, uint256 amount);

    //state variables
    DecentralizedStableCoin private immutable i_dsc;

    address[] public collateralTokens;

    mapping(address => address) public priceFeeds;

    mapping(address => mapping(address => uint256)) public userCollateralBalance;
    mapping(address => uint256) public userMintedDsc;

    //Static
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 150; // 150%
    uint256 private constant LIQUIDATION_BONUS = 10; // 10%

    constructor(address[] memory _collateralTokens, address[] memory _priceFeeds, address dscAddress) {
        if (dscAddress == address(0)) revert DSCEngine_ZeroAddress();
        if (_collateralTokens.length != _priceFeeds.length) {
            revert DSCEngine_TokenAddressAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            if (_collateralTokens[i] == address(0)) revert DSCEngine_ZeroAddress();
            if (_priceFeeds[i] == address(0)) revert DSCEngine_ZeroAddress();
            priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
            collateralTokens.push(_collateralTokens[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function mintDSC(uint256 amountDscToMint) external nonReentrant {
        if (amountDscToMint == 0) revert DSCEngine_NeedMoreThanZero();

        uint256 collateralValue = _getAccountCollateralValueInUsd(msg.sender);
        uint256 newDebtValue = userMintedDsc[msg.sender] + amountDscToMint;

        uint256 healthFactorAfter = (collateralValue * 100 * 1e18) / (LIQUIDATION_THRESHOLD * newDebtValue);

        if (healthFactorAfter < MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorTooLow();
        }

        userMintedDsc[msg.sender] += amountDscToMint;

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) revert DSCEngine_MintFailed();

        emit DSCMinted(msg.sender, amountDscToMint);
    }

    function burnDSC(uint256 amountDscToBurn) external nonReentrant {
        if (amountDscToBurn == 0) revert DSCEngine_NeedMoreThanZero();

        if (userMintedDsc[msg.sender] < amountDscToBurn) {
            revert DSCEngine_BurnAmountExceedsMinted();
        }

        bool success = i_dsc.transferFrom(msg.sender, address(this), amountDscToBurn);
        if (!success) revert DSCEngine_TransferFailed();

        userMintedDsc[msg.sender] -= amountDscToBurn;

        i_dsc.burn(amountDscToBurn);

        emit DSCBurned(msg.sender, amountDscToBurn);
    }

    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine_NeedMoreThanZero();
        if (priceFeeds[token] == address(0)) {
            revert DSCEngine_TokenNotSupported(token);
        }

        userCollateralBalance[msg.sender][token] += amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert DSCEngine_TransferFailed();

        emit CollateralDeposit(msg.sender, token, amount);
    }

    function redeemCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine_NeedMoreThanZero();
        uint256 userBalance = userCollateralBalance[msg.sender][token];
        if (userBalance < amount) revert DSCEngine_InsufficientCollateral();

        uint256 collateralBalanceAfter = _getAccountCollateralValueInUsd(msg.sender) - getUsdValue(token, amount);

        uint256 debtValue = userMintedDsc[msg.sender];

        if (debtValue > 0) {
            uint256 healthFactorAfter = (collateralBalanceAfter * 100 * 1e18) / (LIQUIDATION_THRESHOLD * debtValue);
            if (healthFactorAfter < MIN_HEALTH_FACTOR) {
                revert DSCEngine_HealthFactorTooLow();
            }
        }

        userCollateralBalance[msg.sender][token] -= amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) {
            userCollateralBalance[msg.sender][token] += amount;
            revert DSCEngine_RedeemFailed();
        }

        emit CollateralRedeemed(msg.sender, token, amount, msg.sender);
    }

    function liquidate(address collateral, address user, uint256 debtToCover) external nonReentrant {
        if (i_dsc.balanceOf(msg.sender) < debtToCover) revert DSCEngine_InsufficentDSCBalance();
        uint256 startingHealthFactor = _calculateHealthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorOk();
        }

        if (debtToCover == 0 || userMintedDsc[user] < debtToCover) {
            revert DSCEngine_InvalidDebtAmount();
        }

        bool success = i_dsc.transferFrom(msg.sender, address(this), debtToCover);
        if (!success) revert DSCEngine_TransferFailed();

        i_dsc.burn(debtToCover);
        userMintedDsc[user] -= debtToCover;

        uint256 collateralUsdValue = debtToCover;
        uint256 bonus = (collateralUsdValue * LIQUIDATION_BONUS) / 100;
        uint256 totalCollateralUsd = collateralUsdValue + bonus;

        uint256 collateralAmount = getTokenAmountFromUsd(collateral, totalCollateralUsd);

        uint256 userCollateral = userCollateralBalance[user][collateral];
        if (userCollateral < collateralAmount) {
            collateralAmount = userCollateral;
        }

        userCollateralBalance[user][collateral] -= collateralAmount;
        userCollateralBalance[msg.sender][collateral] += collateralAmount;

        // Note: We don't check if health factor improved because partial liquidations
        // with liquidation bonus can temporarily worsen health factor while still
        // reducing overall system risk by burning bad debt

        emit Liquidation(msg.sender, user, collateral, debtToCover);
    }

    function _getAccountCollateralValueInUsd(address user) private view returns (uint256 totalUsdValue) {
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 tokenAmount = userCollateralBalance[user][token];
            totalUsdValue += getUsdValue(token, tokenAmount);
        }
    }

    function getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        if (price <= 0) revert DSCEngine_InvalidPrice();
        return (uint256(price) * amount) / 1e8;
    }

    function _calculateHealthFactor(address user) private view returns (uint256) {
        uint256 collateralValue = _getAccountCollateralValueInUsd(user);
        uint256 debtValue = userMintedDsc[user];

        if (debtValue == 0) return type(uint256).max;

        uint256 adjustedCollateral = (collateralValue * 100) / LIQUIDATION_THRESHOLD;
        return (adjustedCollateral * 1e18) / debtValue;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _calculateHealthFactor(user);
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        if (price <= 0) revert DSCEngine_InvalidPrice();
        return (usdAmount * 1e8) / uint256(price);
    }
}

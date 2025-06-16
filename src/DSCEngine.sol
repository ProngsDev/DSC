// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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
    error DSCEngine_InsufficientDSCBalance();
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

    //Static - Gas Optimization: Pack constants together
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 150; // 150%
    uint256 private constant LIQUIDATION_BONUS = 10; // 10%
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

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

    /// @notice Mint DSC tokens against deposited collateral
    /// @param amountDscToMint Amount of DSC to mint
    /// @dev Gas optimized: Cache msg.sender, use unchecked math where safe
    function mintDSC(uint256 amountDscToMint) external nonReentrant {
        if (amountDscToMint == 0) revert DSCEngine_NeedMoreThanZero();

        address user = msg.sender; // Gas optimization: Cache msg.sender
        uint256 collateralValue = _getAccountCollateralValueInUsd(user);
        uint256 currentDebt = userMintedDsc[user];

        // Gas optimization: Use unchecked for addition (overflow extremely unlikely)
        uint256 newDebtValue;
        unchecked {
            newDebtValue = currentDebt + amountDscToMint;
        }

        // Gas optimization: Use cached constants and optimize calculation
        uint256 healthFactorAfter = (collateralValue * 100 * PRECISION) / (LIQUIDATION_THRESHOLD * newDebtValue);

        if (healthFactorAfter < MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorTooLow();
        }

        userMintedDsc[user] = newDebtValue; // Gas optimization: Direct assignment vs +=

        bool minted = i_dsc.mint(user, amountDscToMint);
        if (!minted) revert DSCEngine_MintFailed();

        emit DSCMinted(user, amountDscToMint);
    }

    /// @notice Burn DSC tokens to reduce debt
    /// @param amountDscToBurn Amount of DSC to burn
    /// @dev Gas optimized: Cache msg.sender, use unchecked math where safe
    function burnDSC(uint256 amountDscToBurn) external nonReentrant {
        if (amountDscToBurn == 0) revert DSCEngine_NeedMoreThanZero();

        address user = msg.sender; // Gas optimization: Cache msg.sender
        uint256 currentDebt = userMintedDsc[user];

        if (currentDebt < amountDscToBurn) {
            revert DSCEngine_BurnAmountExceedsMinted();
        }

        bool success = i_dsc.transferFrom(user, address(this), amountDscToBurn);
        if (!success) revert DSCEngine_TransferFailed();

        // Gas optimization: Use unchecked for subtraction (underflow checked above)
        unchecked {
            userMintedDsc[user] = currentDebt - amountDscToBurn;
        }

        i_dsc.burn(amountDscToBurn);

        emit DSCBurned(user, amountDscToBurn);
    }

    /// @notice Deposit collateral tokens
    /// @param token Address of the collateral token
    /// @param amount Amount of collateral to deposit
    /// @dev Gas optimized: Cache msg.sender, check token support first
    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine_NeedMoreThanZero();
        if (priceFeeds[token] == address(0)) {
            revert DSCEngine_TokenNotSupported(token);
        }

        address user = msg.sender; // Gas optimization: Cache msg.sender

        // Gas optimization: Use unchecked for addition (overflow extremely unlikely)
        unchecked {
            userCollateralBalance[user][token] += amount;
        }

        bool success = IERC20(token).transferFrom(user, address(this), amount);
        if (!success) revert DSCEngine_TransferFailed();

        emit CollateralDeposit(user, token, amount);
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

    /// @notice Liquidate an undercollateralized position
    /// @param collateral Address of collateral token to seize
    /// @param user Address of user to liquidate
    /// @param debtToCover Amount of DSC debt to cover
    /// @dev Gas optimized: Cache addresses, use unchecked math, optimize calculations
    function liquidate(address collateral, address user, uint256 debtToCover) external nonReentrant {
        // Gas optimization: Early validation to save gas on reverts
        if (priceFeeds[collateral] == address(0)) {
            revert DSCEngine_TokenNotSupported(collateral);
        }
        if (debtToCover == 0) revert DSCEngine_InvalidDebtAmount();

        address liquidator = msg.sender; // Gas optimization: Cache msg.sender

        if (i_dsc.balanceOf(liquidator) < debtToCover) revert DSCEngine_InsufficientDSCBalance();

        uint256 userDebt = userMintedDsc[user];
        if (userDebt < debtToCover) revert DSCEngine_InvalidDebtAmount();

        uint256 startingHealthFactor = _calculateHealthFactor(user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorOk();
        }

        bool success = i_dsc.transferFrom(liquidator, address(this), debtToCover);
        if (!success) revert DSCEngine_TransferFailed();

        i_dsc.burn(debtToCover);

        // Gas optimization: Use unchecked for subtraction (underflow checked above)
        unchecked {
            userMintedDsc[user] = userDebt - debtToCover;
        }

        // Gas optimization: Calculate bonus in one step
        uint256 totalCollateralUsd = debtToCover + (debtToCover * LIQUIDATION_BONUS) / 100;
        uint256 collateralAmount = getTokenAmountFromUsd(collateral, totalCollateralUsd);

        uint256 userCollateral = userCollateralBalance[user][collateral];
        if (userCollateral < collateralAmount) {
            collateralAmount = userCollateral;
        }

        // Gas optimization: Use unchecked for balance updates (underflow/overflow checked)
        unchecked {
            userCollateralBalance[user][collateral] -= collateralAmount;
            userCollateralBalance[liquidator][collateral] += collateralAmount;
        }

        emit Liquidation(liquidator, user, collateral, debtToCover);
    }

    function _getAccountCollateralValueInUsd(address user) private view returns (uint256 totalUsdValue) {
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 tokenAmount = userCollateralBalance[user][token];
            totalUsdValue += getUsdValue(token, tokenAmount);
        }
    }

    /// @notice Get USD value of token amount using Chainlink price feeds
    /// @param token Address of the token
    /// @param amount Amount of tokens
    /// @return USD value normalized to 18 decimals
    /// @dev Gas optimized: Cache external calls, use proper decimal handling
    function getUsdValue(address token, uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        if (price <= 0) revert DSCEngine_InvalidPrice();

        // Gas optimization: Cache external calls
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 priceFeedDecimals = priceFeed.decimals();

        // Calculate USD value with proper decimal handling
        // Formula: (price * amount * 1e18) / (10^priceFeedDecimals * 10^tokenDecimals)
        // This normalizes to 18 decimal places for consistent USD representation
        uint256 priceWithDecimals = uint256(price) * (10 ** (18 - priceFeedDecimals));
        return (priceWithDecimals * amount) / (10 ** tokenDecimals);
    }

    /// @notice Calculate health factor for a user
    /// @param user Address of the user
    /// @return Health factor (1e18 = 100%)
    /// @dev Gas optimized: Use cached constants, early return for zero debt
    function _calculateHealthFactor(address user) private view returns (uint256) {
        uint256 debtValue = userMintedDsc[user];

        // Gas optimization: Early return for zero debt
        if (debtValue == 0) return type(uint256).max;

        uint256 collateralValue = _getAccountCollateralValueInUsd(user);

        // Gas optimization: Use cached constants and optimize calculation
        uint256 adjustedCollateral = (collateralValue * 100) / LIQUIDATION_THRESHOLD;
        return (adjustedCollateral * PRECISION) / debtValue;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _calculateHealthFactor(user);
    }

    /// @notice Convert USD amount to token amount using Chainlink price feeds
    /// @param token Address of the token
    /// @param usdAmount USD amount (18 decimals)
    /// @return Token amount in token's native decimals
    /// @dev Gas optimized: Cache external calls, use proper decimal handling
    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();

        if (price <= 0) revert DSCEngine_InvalidPrice();

        // Gas optimization: Cache external calls
        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        uint8 priceFeedDecimals = priceFeed.decimals();

        // Calculate token amount with proper decimal handling
        // Formula: (usdAmount * 10^tokenDecimals * 10^priceFeedDecimals) / (price * 1e18)
        // usdAmount is expected to be in 18 decimal format
        uint256 adjustedUsdAmount = usdAmount * (10 ** (tokenDecimals + priceFeedDecimals));
        return adjustedUsdAmount / (uint256(price) * PRECISION);
    }
}

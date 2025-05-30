// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine is ReentrancyGuard {
    //errors

    error DSCEngine_TokenAddressAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine_NeedMoreThanZero();
    error DSCEngine_TokenNotSupported(address token);
    error DSCEngine_TransferFailed();
    error DSCEngine_InsufficientCollateral();
    error DSCEngine_RedeemFailed();
    error DSCEngine_HealthFactorTooLow();
    error DSCEngine_HealthFactorTooHigh();
    error DSCEngine_MintFailed();
    error DSCEngine_BurnAmountExceedsMinted();

    //types

    //state variables
    DecentralizedStableCoin private immutable i_dsc;

    address[] public collateralTokens;

    mapping(address => address) public priceFeeds;
    mapping(address => address) public collateralBalance;

    mapping(address => mapping(address => uint256)) public userCollateralBalance;
    mapping(address => uint256) public userMintedDsc;

    //Static
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    constructor(address[] memory _collateralTokens, address[] memory _priceFeeds, address dscAddress) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert DSCEngine_TokenAddressAndPriceFeedAddressesAmountsDontMatch();
        }

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
            collateralTokens.push(_collateralTokens[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function mintDSC(uint256 amountDscToMint) external nonReentrant {
        if (amountDscToMint == 0) revert DSCEngine_NeedMoreThanZero();

        userMintedDsc[msg.sender] += amountDscToMint;

        if (_calculateHealthFactor(msg.sender) < MIN_HEALTH_FACTOR) {
            userMintedDsc[msg.sender] -= amountDscToMint;
            revert DSCEngine_HealthFactorTooLow();
        }

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) revert DSCEngine_MintFailed();
    }

    function burnDSC(uint256 amountDscToBurn) external nonReentrant {
        if (amountDscToBurn == 0) revert DSCEngine_NeedMoreThanZero();

        if (userMintedDsc[msg.sender] < amountDscToBurn) {
            revert DSCEngine_BurnAmountExceedsMinted();
        }

        userMintedDsc[msg.sender] -= amountDscToBurn;

        bool success = i_dsc.transferFrom(msg.sender, address(this), amountDscToBurn);
        if (!success) revert DSCEngine_TransferFailed();

        i_dsc.burn(amountDscToBurn);
    }

    function depositCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine_NeedMoreThanZero();
        if (priceFeeds[token] == address(0)) {
            revert DSCEngine_TokenNotSupported(token);
        }

        userCollateralBalance[msg.sender][token] += amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert DSCEngine_TransferFailed();
        //Future: emit event
    }

    function redeemCollateral(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert DSCEngine_NeedMoreThanZero();
        uint256 userBalance = userCollateralBalance[msg.sender][token];
        if (userBalance < amount) revert DSCEngine_InsufficientCollateral();

        userCollateralBalance[msg.sender][token] -= amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert DSCEngine_RedeemFailed();
    }

    function _calculateHealthFactor(address user) private view returns (uint256) {}
}

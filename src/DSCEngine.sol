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

    //types

    //state variables
    DecentralizedStableCoin private immutable i_dsc;

    address[] public collateralTokens;

    mapping(address => address) public priceFeeds;
    mapping(address => address) public collateralBalance;

    mapping(address => mapping(address => uint256)) public userCollateralBalance;

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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine is ReentrancyGuard {
    //errors

    error DSCEngine_TokenAddressAndPriceFeedAddressesAmountsDontMatch();

    //types

    //state variables
    DecentralizedStableCoin private immutable i_dsc;

    address[] public collateralTokens;

    mapping(address => address) public priceFeeds;

    mapping(address => address) public collateralBalance;

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
}

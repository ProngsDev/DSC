// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin_NotZeroAddress();
    error DecentralizedStableCoin_AmountMustBeGreaterThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) revert DecentralizedStableCoin_NotZeroAddress();
        if (_amount <= 0) {
            revert DecentralizedStableCoin_AmountMustBeGreaterThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount < 0) {
            revert DecentralizedStableCoin_AmountMustBeGreaterThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin_BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @notice ERC20 implementation of a decentralized stablecoin
 * @dev Gas optimized with custom errors and efficient validation
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    // Gas optimization: Custom errors are more efficient than require statements
    error DecentralizedStableCoin_NotZeroAddress();
    error DecentralizedStableCoin_AmountMustBeGreaterThanZero();
    error DecentralizedStableCoin_BurnAmountExceedsBalance();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    /// @notice Mint DSC tokens to specified address
    /// @param _to Address to mint tokens to
    /// @param _amount Amount of tokens to mint
    /// @return success True if minting succeeded
    /// @dev Gas optimized: Early validation, single return statement
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        // Gas optimization: Check zero address first (most likely to fail)
        if (_to == address(0)) revert DecentralizedStableCoin_NotZeroAddress();
        if (_amount == 0) revert DecentralizedStableCoin_AmountMustBeGreaterThanZero();

        _mint(_to, _amount);
        return true;
    }

    /// @notice Burn DSC tokens from caller's balance
    /// @param _amount Amount of tokens to burn
    /// @dev Gas optimized: Early validation before calling parent
    function burn(uint256 _amount) public override onlyOwner {
        if (_amount == 0) revert DecentralizedStableCoin_AmountMustBeGreaterThanZero();
        super.burn(_amount);
    }
}

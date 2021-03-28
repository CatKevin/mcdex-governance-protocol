// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "hardhat/console.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

contract ConstantSeller {
    using SafeERC20 for IERC20;

    address public owner;
    uint256 public price;
    uint256 public normalizedPrice;

    IERC20 public tokenIn;
    IERC20 public tokenOut;

    constructor(
        address tokenIn_,
        address tokenOut_,
        uint256 price_
    ) {
        owner = msg.sender;
        tokenIn = IERC20(tokenIn_);
        tokenOut = IERC20(tokenOut_);
        normalizedPrice = price_;

        uint8 decimalsIn = IDecimals(tokenIn_).decimals();
        uint8 decimalsOut = IDecimals(tokenOut_).decimals();

        if (decimalsIn > decimalsOut) {
            price = price_ / (10**(decimalsIn - decimalsOut));
        } else if (decimalsIn < decimalsOut) {
            price = price_ * (10**(decimalsOut - decimalsIn));
        } else {
            price = price_;
        }
    }

    function setPrice(uint256 price_) public {
        price = price_;
    }

    function convert(uint256 amount) public returns (uint256, uint256) {
        require(price != 0, "no price");
        require(amount > 0, "0 amount");

        uint256 amountToReturn = (amount * price) / 1e18;
        tokenIn.transferFrom(msg.sender, address(this), amount);
        tokenOut.transfer(msg.sender, amountToReturn);
        return (normalizedPrice, amountToReturn);
    }
}

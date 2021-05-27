// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "./ConstantSeller.sol";

interface ISeller {
    function setPrice(uint256 price_) external;

    function exchange(uint256 amount) external returns (uint256, uint256);
}

contract ConstantSellerFactory {
    mapping(bytes32 => address) internal _swaps;

    event CreateSeller(
        address indexed newSeller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 initialPrice
    );

    function createSeller(
        address tokenIn,
        address tokenOut,
        uint256 initialPrice
    ) external returns (address) {
        address newSeller = address(new ConstantSeller(tokenIn, tokenOut, initialPrice));
        _swaps[_id(msg.sender, tokenIn, tokenOut)] = newSeller;
        emit CreateSeller(newSeller, tokenIn, tokenOut, initialPrice);
        return newSeller;
    }

    function getSeller(address tokenIn, address tokenOut) external view returns (address) {
        return _swaps[_id(msg.sender, tokenIn, tokenOut)];
    }

    function setPrice(
        address tokenIn,
        address tokenOut,
        uint256 price
    ) external {
        address seller = _swaps[_id(msg.sender, tokenIn, tokenOut)];
        ISeller(seller).setPrice(price);
    }

    function _id(
        address account,
        address inToken,
        address outToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(account, inToken, outToken));
    }
}

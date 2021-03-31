// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IUSDConvertor {
    function tokenIn() external view returns (address);

    function tokenOut() external view returns (address);

    function exchange(uint256 amountIn)
        external
        returns (uint256 normalizedPrice, uint256 amountOut);
}

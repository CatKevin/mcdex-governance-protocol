// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IUSDConvertor {
    function tokenIn() external view returns (address token);

    function tokenOut() external view returns (address token);

    function covertToUSD(uint256 tokenAmount) external returns (uint256 usdAmount);
}

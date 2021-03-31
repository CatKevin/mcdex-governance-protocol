// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface ITWAPOracle {
    function priceTWAP() external view returns (uint256);
}

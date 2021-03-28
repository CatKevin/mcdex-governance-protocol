// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract MockTWAPOracle {
    uint256 public mockPrice;

    function setPrice(uint256 newPrice) external {
        mockPrice = newPrice;
    }

    function priceTWAP() external view returns (uint256) {
        return mockPrice;
    }
}

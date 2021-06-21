// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../components/staking/RewardDistribution.sol";

contract TestRewardDistribution is RewardDistribution {
    uint256 public mockBlockNumber;

    function setBlockNumber(uint256 blockNumber) public {
        mockBlockNumber = blockNumber;
    }

    function skipBlock(uint256 count) public {
        if (mockBlockNumber == 0) {
            mockBlockNumber = block.number;
        }
        mockBlockNumber = mockBlockNumber + count;
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        if (mockBlockNumber > 0) {
            return mockBlockNumber;
        }
        return block.number;
    }
}

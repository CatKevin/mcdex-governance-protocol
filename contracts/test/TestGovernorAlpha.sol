// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../GovernorAlpha.sol";

contract TestGovernorAlpha is GovernorAlpha {
    address public mockMCB;
    uint256 public mockBlockNumber;
    uint256 public mockBlockTimestamp;

    function skipBlock(uint256 count) public {
        if (mockBlockNumber == 0) {
            mockBlockNumber = block.number;
        }
        mockBlockNumber = mockBlockNumber + count;
    }

    function setBlockNumber(uint256 blockNumber) public {
        mockBlockNumber = blockNumber;
    }

    function setTimestamp(uint256 newTimestamp) public {
        mockBlockTimestamp = newTimestamp;
    }

    function skipTime(uint256 nSeconds) public {
        if (mockBlockTimestamp == 0) {
            mockBlockTimestamp = block.timestamp;
        }
        mockBlockTimestamp = mockBlockTimestamp + nSeconds;
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return mockBlockNumber == 0 ? block.number : mockBlockNumber;
    }

    function _getBlockTimestamp() internal view virtual override returns (uint256) {
        return mockBlockTimestamp == 0 ? block.timestamp : mockBlockTimestamp;
    }

    function votingPeriod() public pure virtual override returns (uint256) {
        return 20;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../GovernorAlpha.sol";

contract TestGovernorAlpha is GovernorAlpha {
    uint256 public mockBlockNumber;
    uint256 public mockBlockTimestamp;

    constructor(
        address timelock_,
        address comp_,
        address guardian_
    ) public GovernorAlpha(timelock_, comp_, guardian_) {}

    function skipBlock(uint256 count) public {
        if (mockBlockNumber == 0) {
            mockBlockNumber = block.number;
        }
        mockBlockNumber = mockBlockNumber + count;
    }

    function getBlockNumber() internal view virtual override returns (uint256) {
        if (mockBlockNumber > 0) {
            return mockBlockNumber;
        }
        return block.number;
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

    function getBlockTimestamp() internal view virtual override returns (uint256) {
        if (mockBlockTimestamp > 0) {
            return mockBlockTimestamp;
        }
        return block.timestamp;
    }
}

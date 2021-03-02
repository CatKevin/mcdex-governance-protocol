// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Timelock.sol";

contract TestTimelock is Timelock {
    uint256 public mockBlockTimestamp;

    constructor(address admin_, uint256 delay_) Timelock(admin_, delay_) {}

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

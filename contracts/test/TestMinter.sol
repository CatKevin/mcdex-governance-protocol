// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import { MCBMinter } from "../minter/MCBMinter.sol";

contract TestMCBMinter is MCBMinter {
    uint256 public mockBlockNumber;

    function setBlockNumber(uint256 blockNumber) public {
        mockBlockNumber = blockNumber;
    }

    function _blockNumber() internal view virtual override returns (uint256) {
        if (mockBlockNumber == 0) {
            return block.number;
        }
        return mockBlockNumber;
    }
}

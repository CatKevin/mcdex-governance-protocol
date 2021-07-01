// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import { MCBMinter } from "../minter/MCBMinter.sol";
import "./TimeMachine.sol";

contract TestMCBMinter is MCBMinter {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function _blockNumber() internal view virtual override returns (uint256) {
        return timeMachine.blockNumber();
    }
}

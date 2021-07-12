// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../XMCB.sol";
import "./TimeMachine.sol";

contract TestXMCB is XMCB {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function getBlockNumber() internal view virtual override returns (uint256) {
        return timeMachine.blockNumber();
    }

    function getBlockTimestamp() internal view virtual override returns (uint256) {
        return timeMachine.blockTime();
    }
}

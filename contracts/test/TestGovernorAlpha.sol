// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../GovernorAlpha.sol";
import "./TimeMachine.sol";

contract TestGovernorAlpha is GovernorAlpha {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return timeMachine.blockNumber();
    }

    function _getBlockTimestamp() internal view virtual override returns (uint256) {
        return timeMachine.blockTime();
    }
}

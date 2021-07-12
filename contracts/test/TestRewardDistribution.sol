// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../components/staking/RewardDistribution.sol";
import "./TimeMachine.sol";

contract TestRewardDistribution is RewardDistribution {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return timeMachine.blockNumber();
    }
}

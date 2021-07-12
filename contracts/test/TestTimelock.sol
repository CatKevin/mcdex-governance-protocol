// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Timelock.sol";
import "./TimeMachine.sol";

contract TestTimelock is Timelock {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function getBlockTimestamp() internal view virtual override returns (uint256) {
        return timeMachine.blockTime();
    }

    function forceSetDelay(uint256 delay_) public {
        delay = delay_;
    }
}

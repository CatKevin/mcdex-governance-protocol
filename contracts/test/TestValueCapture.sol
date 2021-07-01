// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../ValueCapture.sol";
import "./TimeMachine.sol";

contract TestValueCapture is ValueCapture {
    TimeMachine public timeMachine;

    constructor(address _timeMachine) {
        timeMachine = TimeMachine(_timeMachine);
    }

    function _blockNumber() internal view virtual override returns (uint256) {
        return timeMachine.blockNumber();
    }
}

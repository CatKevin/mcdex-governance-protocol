// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../LPGovernor.sol";

/*
    LPGovernor:
        - stake/withdraw    √
        - minging           √
        - delegate          √
        - propose/vote      √
*/

contract TestLPGovernor is LPGovernor {
    function quorumVotes() public pure virtual override returns (uint256) {
        return 1e17;
    } // 10%

    function proposalThreshold() public pure virtual override returns (uint256) {
        return 1e16;
    } // 1%

    function proposalMaxOperations() public pure virtual override returns (uint256) {
        return 10;
    } // 10 actions

    function votingDelay() public pure virtual override returns (uint256) {
        return 1;
    } // 1 block

    function votingPeriod() public pure virtual override returns (uint256) {
        return 20;
    }

    function gracePeriod() public pure virtual override returns (uint256) {
        return 20;
    }

    function unlockPeriod() public pure virtual override returns (uint256) {
        return 20;
    }
}

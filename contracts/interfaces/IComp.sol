// SPDX-License-Identifier: BSD
pragma solidity 0.7.4;

interface IComp {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IDelegate {
    function getPriorVotes(address account, uint256 blockNumber)
        external
        view
        virtual
        returns (uint256);
}

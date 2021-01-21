// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

interface ILPGovernor {
    // stake share
    function stake(uint256 amount) external;

    // withdraw share
    function withdraw(uint256 amount) external;

    // set delegatee to delegatee vote
    function delegate(address delegatee) external;

    // create proposal
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    // push a success proposal into queue, wait for execution after timelock
    function queue(uint256 proposalId) external;

    // execute a queued proposal
    function execute(uint256 proposalId) external payable;

    // vote to support or against a proposal
    function castVote(uint256 proposalId, bool support) external;

    // get reward earned till now
    function earned(address account) external view returns (uint256);

    // claim reward till now
    function getReward() external;
}

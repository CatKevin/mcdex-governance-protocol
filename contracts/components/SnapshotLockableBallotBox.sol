// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../libraries/SafeMathExt.sol";
import "../libraries/SnapshotOperation.sol";
import "./LockableBallotBox.sol";

abstract contract SnapshotLockableBallotBox is LockableBallotBox {
    using SafeMathExt for uint256;
    using SafeMathUpgradeable for uint256;
    using SnapshotOperation for Snapshot;

    event SaveVoteBalanceCheckpoint(address indexed account, uint256 balance);

    mapping(address => Snapshot) internal _voteBalanceSnapshot;

    function __SnapshotLockableBallotBox_init_unchained() internal initializer {}

    function getVoteBalanceCheckpointCount(address account) public view returns (uint256) {
        return _voteBalanceSnapshot[account].count;
    }

    function getVoteBalanceCheckpointAt(address account, uint256 checkpointIndex)
        public
        view
        returns (uint256, uint256)
    {
        Checkpoint storage checkpoint = _voteBalanceSnapshot[account].checkpoints[checkpointIndex];
        return (checkpoint.fromBlock, checkpoint.value);
    }

    function getVoteBalanceAt(address account, uint256 blockNumber)
        public
        view
        virtual
        returns (uint256)
    {
        return _voteBalanceSnapshot[account].findCheckpoint(blockNumber);
    }

    function getPriorVotes(address account, uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 totalBalance =
            IShareToken(_shareToken).getBalanceAt(account, blockNumber).add(
                getVoteBalanceAt(account, blockNumber)
            );
        uint256 currentBalance = getVoteBalanceAt(account, block.number.sub(1));
        return totalBalance.min(currentBalance);
    }

    function getPriorThreshold(uint256 blockNumber) public view virtual override returns (uint256) {
        uint256 effectiveTotalSupply = IShareToken(_shareToken).getTotalSupplyAt(blockNumber);
        return effectiveTotalSupply.mul(proposalThreshold()).div(1e18);
    }

    function stake(uint256 amount) public virtual override {
        super.stake(amount);
        _saveBalanceCheckpoint(msg.sender);
    }

    function withdraw(uint256 amount) public virtual override {
        super.withdraw(amount);
        _saveBalanceCheckpoint(msg.sender);
    }

    function _saveBalanceCheckpoint(address account) internal {
        if (account == address(0)) {
            return;
        }
        uint256 voteBalance = getVoteBalance(account);
        _voteBalanceSnapshot[account].saveCheckpoint(voteBalance);
        emit SaveVoteBalanceCheckpoint(account, voteBalance);
    }
}

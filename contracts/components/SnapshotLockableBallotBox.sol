// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./LockableBallotBox.sol";

abstract contract SnapshotLockableBallotBox is LockableBallotBox {
    using SafeMathUpgradeable for uint256;

    function __SnapshotLockableBallotBox_init_unchained() internal initializer {}

    function getPriorVotes(address account, uint256 blockNumber)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 effectiveBalance = IShareToken(_shareToken).getBalanceAt(account, blockNumber);
        uint256 voteBalance = getVoteBalance(account);
        return MathUpgradeable.min(effectiveBalance, voteBalance);
    }

    function getPriorThreshold(uint256 blockNumber) public view virtual override returns (uint256) {
        uint256 effectiveTotalSupply = IShareToken(_shareToken).getTotalSupplyAt(blockNumber);
        return effectiveTotalSupply.mul(proposalThreshold()).div(1e18);
    }
}

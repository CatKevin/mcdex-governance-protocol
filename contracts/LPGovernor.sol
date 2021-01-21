// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./interface/ILPGovernor.sol";
import "./components/ShareBank.sol";
import "./components/Mining.sol";
import "./components/SnapshotLockableBallotBox.sol";

/*
    LPGovernor:
        - stake/withdraw    √
        - minging           √
        - delegate          √
        - propose/vote      √
*/

contract LPGovernor is Initializable, ShareBank, Mining, SnapshotLockableBallotBox {
    bytes32 public constant SIGNATURE_PERPETUAL_UPGRADE =
        keccak256(bytes("upgradeTo(address,address)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SETTLE =
        keccak256(bytes("forceToSetEmergencyState(uint256)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SET_OPERATOR =
        keccak256(bytes("setOperator(address)"));
    address public liquidityPool;

    function initialize(
        address shareToken_,
        address rewardToken_,
        address timelock_,
        address guardian_
    ) public initializer {
        __Ownable_init_unchained();
        __Bank_init_unchained(shareToken_);
        __RewardDistribution_init_unchained(rewardToken_);
        __Mining_init_unchained();
        __BallotBox_init_unchained(timelock_, guardian_);
        __ShareLock_init_unchained();
        __SnapshotLockableBallotBox_init_unchained();
    }

    function criticalQuorumVotes() public pure returns (uint256) {
        return 2e17; // 20%
    }

    function isCriticalFunction(string memory functionSignature) public pure returns (bool) {
        bytes32 functionHash = keccak256(bytes(functionSignature));
        return
            functionHash == SIGNATURE_PERPETUAL_UPGRADE ||
            functionHash == SIGNATURE_PERPETUAL_SETTLE ||
            functionHash == SIGNATURE_PERPETUAL_SET_OPERATOR;
    }

    function getQuorumVotes(uint256 proposalId) public view virtual override returns (uint256) {
        Proposal storage proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            if (
                proposal.targets[i] == liquidityPool && isCriticalFunction(proposal.signatures[i])
            ) {
                return criticalQuorumVotes();
            }
        }
        return quorumVotes();
    }

    function stake(uint256 amount)
        public
        virtual
        override(ShareBank, Delegate)
        updateReward(msg.sender)
    {
        super.stake(amount);
    }

    function withdraw(uint256 amount)
        public
        virtual
        override(ShareBank, LockableBallotBox)
        updateReward(msg.sender)
    {
        super.withdraw(amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./interface/ILPGovernor.sol";
import "./components/ShareBank.sol";
import "./components/Mining.sol";
import "./components/LockableBallotBox.sol";

/*
    LPGovernor:
        - stake/withdraw    √
        - minging           √
        - delegate          √
        - propose/vote      √
*/

contract LPGovernor is Initializable, ShareBank, Mining, LockableBallotBox {
    bytes32 public constant SIGNATURE_PERPETUAL_UPGRADE =
        keccak256(bytes("upgradeTo(address,address)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SETTLE =
        keccak256(bytes("forceToSetEmergencyState(uint256)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SET_OPERATOR =
        keccak256(bytes("setOperator(address)"));
    address public liquidityPool;

    modifier onlyUnlocked() {
        require(!isLocked(msg.sender), "share locked by voting");
        _;
    }

    function __LPGovernor_init(
        address shareToken_,
        address timelock_,
        address guardian_
    ) internal initializer {
        __BallotBox_init_unchained(timelock_, guardian_);
        __LPGovernor_init_unchained(shareToken_);
        __Bank_init_unchained(shareToken_);
    }

    function __LPGovernor_init_unchained(address shareToken_) internal initializer {}

    function criticalQuorumVotes() public pure returns (uint256) {
        return 2e17; // 20%
    }

    function isCriticalFunction(string memory functionSignature) public view returns (bool) {
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

    // function getPriorVotes(address account, uint256 blockNumber)
    //     public
    //     view
    //     virtual
    //     override(Delegate, Delegate)
    //     returns (uint256)
    // {
    //     return Delegate.getPriorVotes(account, blockNumber);
    // }

    function stake(uint256 amount)
        public
        virtual
        override(ShareBank, Delegate)
        updateReward(msg.sender)
    {
        ShareBank.stake(amount);
    }

    function withdraw(uint256 amount)
        public
        virtual
        override(ShareBank, Delegate)
        updateReward(msg.sender)
        onlyUnlocked
    {
        ShareBank.withdraw(amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "../interface/IShareToken.sol";
import "../interface/ITimeLock.sol";
import "./Delegate.sol";
import "./Signature.sol";

import "hardhat/console.sol";

/// @notice Possible states that a proposal may be in
enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }

struct Proposal {
    // Unique id for looking up a proposal
    uint256 id;
    // Creator of the proposal
    address proposer;
    // The timestamp that the proposal will be available for execution, set once the vote succeeds
    uint256 eta;
    // the ordered list of target addresses for calls to be made
    address[] targets;
    // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
    uint256[] values;
    // The ordered list of function signatures to be called
    string[] signatures;
    // The ordered list of calldata to be passed to each call
    bytes[] calldatas;
    // The block at which voting begins: holders must delegate their votes prior to this block
    uint256 startBlock;
    // The block at which voting ends: votes must be cast prior to this block
    uint256 endBlock;
    // Current number of votes in favor of this proposal
    uint256 forVotes;
    // Current number of votes in opposition to this proposal
    uint256 againstVotes;
    // Flag marking whether the proposal has been canceled
    bool canceled;
    // Flag marking whether the proposal has been executed
    bool executed;
    // Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;
}

/// @notice Ballot receipt record for a voter
struct Receipt {
    // Whether or not a vote has been cast
    bool hasVoted;
    // Whether or not the voter supports the proposal
    bool support;
    // The number of votes the voter had, which were cast
    uint256 votes;
}

abstract contract BallotBox is Initializable, Signature, Delegate {
    using SafeMathUpgradeable for uint256;

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice The address of the Compound Protocol Timelock
    // ITimeLock public timelock;

    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    function __BallotBox_init() internal virtual initializer {
        __BallotBox_init_unchained();
    }

    function __BallotBox_init_unchained() internal initializer {
        // timelock = ITimeLock(timelock_);
        // guardian = guardian_;
    }

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached
    ///         and for a vote to succeed
    function quorumVotes() public pure virtual returns (uint256) {
        return 1e17;
    } // 10%

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThreshold() public pure virtual returns (uint256) {
        return 1e16;
    } // 1%

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure virtual returns (uint256) {
        return 10;
    } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure virtual returns (uint256) {
        return 1;
    } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure virtual returns (uint256) {
        return 17280;
    } // ~3 days in blocks (assuming 15s blocks)

    function gracePeriod() public pure virtual returns (uint256) {
        return 11520;
    } // ~3 days in blocks (assuming 15s blocks)

    function unlockPeriod() public pure virtual returns (uint256) {
        return 17280;
    } // ~3 days in blocks (assuming 15s blocks)

    function getPriorVotes(address account, uint256) public view virtual returns (uint256) {
        return getVoteBalance(account);
    }

    function getPriorThreshold(uint256) public view virtual returns (uint256) {
        uint256 effectiveTotalSupply = IShareToken(_shareToken).totalSupply();
        return effectiveTotalSupply.mul(proposalThreshold()).div(1e18);
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) internal virtual returns (uint256) {
        uint256 priorVotes = getPriorVotes(msg.sender, block.number.sub(1));
        require(
            priorVotes > getPriorThreshold(block.number.sub(1)),
            "proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "proposal function information arity mismatch"
        );
        require(targets.length != 0, "must provide actions");
        require(targets.length <= proposalMaxOperations(), "too many actions");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                "one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "one live proposal per proposer, found an already pending proposal"
            );
        }

        uint256 startBlock = block.number.add(votingDelay());
        uint256 endBlock = startBlock.add(votingPeriod());

        proposalCount++;
        uint256 proposalId = proposalCount;
        proposals[proposalId].id = proposalId;
        proposals[proposalId].proposer = msg.sender;
        proposals[proposalId].targets = targets;
        proposals[proposalId].values = values;
        proposals[proposalId].signatures = signatures;
        proposals[proposalId].calldatas = calldatas;
        proposals[proposalId].startBlock = startBlock;
        proposals[proposalId].endBlock = endBlock;
        proposals[proposalId].forVotes = priorVotes;
        proposals[proposalId].receipts[msg.sender] = Receipt({
            hasVoted: true,
            support: true,
            votes: priorVotes
        });
        latestProposalIds[msg.sender] = proposalId;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        emit VoteCast(msg.sender, proposalId, true, priorVotes);
        return proposalId;
    }

    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "proposal can only be executed if it is success and queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.endBlock
            );
        }
        emit ProposalExecuted(proposalId);
    }

    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        uint256 blockNumber = _getBlockNumber();
        require(blockNumber >= eta.add(gracePeriod()), "Transaction hasn't surpassed time lock.");
        require(blockNumber <= eta.add(gracePeriod()).add(unlockPeriod()), "Transaction is stale.");

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            console.log("***", target);
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{ value: value }(callData);
        require(success, "Transaction execution reverted.");
        emit ExecuteTransaction(txHash, target, value, signature, data, eta);
        return returnData;
    }

    function getActions(uint256 proposalId)
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < getQuorumVotes(proposalId)
        ) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.number <= proposal.endBlock.add(gracePeriod())) {
            return ProposalState.Queued;
        } else if (block.number > proposal.endBlock.add(gracePeriod()).add(unlockPeriod())) {
            return ProposalState.Expired;
        } else if (!proposal.executed) {
            return ProposalState.Succeeded;
        }
    }

    function getQuorumVotes(uint256) public view virtual returns (uint256) {
        return quorumVotes();
    }

    function castVote(uint256 proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(
        uint256 proposalId,
        bool support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 domainSeparator =
            keccak256(
                abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this))
            );
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal virtual {
        require(state(proposalId) == ProposalState.Active, "voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "voter already voted");
        uint256 votes = getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function _getBlockNumber() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.number;
    }
}

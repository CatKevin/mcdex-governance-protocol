// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../libraries/SafeMathExt.sol";

import "./Signature.sol";
import "./ShareBank.sol";

contract Delegate is ShareBank, Signature {
    using SafeMathUpgradeable for uint256;
    using SafeMathExt for uint256;

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    mapping(address => address) internal _delegates;

    mapping(address => uint256) internal _nonces;

    mapping(address => uint256) internal _voteBalances;

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    function getDelegate(address account) public view virtual returns (address) {
        return _delegates[account] == address(0) ? account : _delegates[account];
    }

    function getNonce(address account) public view returns (uint256) {
        return _nonces[account];
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getVoteBalance(address account) public view virtual returns (uint256) {
        return _voteBalances[account];
    }

    function stake(uint256 amount) public virtual override {
        super.stake(amount);
        address account = msg.sender;
        address delegatee = getDelegate(account);
        _moveDelegates(address(0), delegatee, amount);
    }

    function withdraw(uint256 amount) public virtual override {
        address account = msg.sender;
        address delegatee = getDelegate(account);
        _moveDelegates(delegatee, address(0), amount);
        super.withdraw(amount);
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "delegateBySig: invalid signature");
        require(nonce == _nonces[signatory]++, "delegateBySig: invalid nonce");
        require(block.timestamp <= expiry, "delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate =
            _delegates[delegator] == address(0) ? delegator : _delegates[delegator];
        uint256 delegatorBalance = _balances[delegator];
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal virtual {
        if (srcRep != dstRep && amount > 0) {
            if (dstRep != address(0)) {
                _voteBalances[dstRep] = _voteBalances[dstRep].add(amount);
            }
            if (srcRep != address(0)) {
                _voteBalances[srcRep] = _voteBalances[srcRep].sub(amount);
            }
        }
    }
}

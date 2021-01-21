// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./interface/ILPGovernor.sol";
import "./components/ShareBank.sol";
import "./components/Dividends.sol";
import "./components/LockableBallotBox.sol";

/*
    DAOGovernance:
        - stake/withdraw    √
        - minging           √
        - delegate          √
        - propose/vote      √
        - vault
        - valueCapture
*/

contract DAOGovernance is Initializable, ShareBank, Dividends, LockableBallotBox {
    modifier onlyUnlocked() {
        require(!isLocked(msg.sender), "share locked by voting");
        _;
    }

    function __DAOGovernance_init(
        address shareToken_,
        address timelock_,
        address guardian_
    ) internal initializer {
        __Bank_init_unchained(shareToken_);
        __BallotBox_init_unchained(timelock_, guardian_);
        __DAOGovernance_init_unchained(shareToken_);
    }

    function __DAOGovernance_init_unchained(address shareToken_) internal initializer {}

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

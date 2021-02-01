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

contract DAOGovernance is Initializable, Dividends, LockableBallotBox {
    function __DAOGovernance_init(address shareToken_) internal initializer {
        __BallotBox_init_unchained();
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

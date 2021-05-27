// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../GovernorAlpha.sol";

contract FastGovernorAlpha is GovernorAlpha {
    address public mockMCB;
    uint256 public mockBlockNumber;
    uint256 public mockBlockTimestamp;

    constructor(
        address dataExchange_,
        address timelock_,
        address comp_,
        address guardian_,
        uint256 initialProposalId_
    ) GovernorAlpha(dataExchange_, timelock_, comp_, guardian_, initialProposalId_) {}

    function votingPeriod() public pure virtual override returns (uint256) {
        return 60;
    }
}

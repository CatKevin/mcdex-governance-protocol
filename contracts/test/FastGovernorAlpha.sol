// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../GovernorAlpha.sol";

contract FastGovernorAlpha is GovernorAlpha {
    address public mockMCB;
    uint256 public mockBlockNumber;
    uint256 public mockBlockTimestamp;

    function votingPeriod() public pure virtual override returns (uint256) {
        return 80;
    }

    function _getMCBTotalSupply() internal view virtual override returns (uint256) {
        return mcbToken.totalSupply();
    }
}
W
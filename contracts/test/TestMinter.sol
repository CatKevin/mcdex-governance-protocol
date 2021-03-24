// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Minter.sol";

contract TestMinter is Minter {
    uint256 internal _mockBlockNumber;

    constructor(
        address mcbToken_,
        address valueCapture_,
        address devAccount_,
        Release memory default_,
        Release memory seriesA_
    ) Minter(mcbToken_, valueCapture_, devAccount_, default_, seriesA_) {}

    function setBlockNumber(uint256 blockNumber) public {
        _mockBlockNumber = blockNumber;
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return _mockBlockNumber;
    }
}

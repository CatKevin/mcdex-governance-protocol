// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Minter.sol";

contract TestMinter is Minter {
    uint256 internal _mockBlockNumber;

    constructor(
        address mcbToken_,
        address valueCapture_,
        address seriesA_,
        address devAccount_,
        uint256 baseMaxSupply_,
        uint256 seriesAMaxSupply_,
        uint256 baseMinReleaseRate_,
        uint256 seriesAMaxReleaseRate_
    )
        Minter(
            mcbToken_,
            valueCapture_,
            seriesA_,
            devAccount_,
            baseMaxSupply_,
            seriesAMaxSupply_,
            baseMinReleaseRate_,
            seriesAMaxReleaseRate_
        )
    {}

    function setBlockNumber(uint256 blockNumber) public {
        _mockBlockNumber = blockNumber;
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return _mockBlockNumber;
    }
}

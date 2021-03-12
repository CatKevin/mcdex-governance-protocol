// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "../Minter.sol";

contract TestMinter is Minter {
    uint256 internal _mockTimestamp;

    constructor(
        address mcbToken_,
        address valueCapture_,
        address devAccount_,
        uint256 devShareRate_,
        uint256 totalSupplyLimit_,
        uint256 beginTime_,
        uint256 dailySupplyLimit_
    )
        Minter(
            mcbToken_,
            valueCapture_,
            devAccount_,
            devShareRate_,
            totalSupplyLimit_,
            beginTime_,
            dailySupplyLimit_
        )
    {}

    function setTimestamp(uint256 timestamp) public {
        _mockTimestamp = timestamp;
    }

    function getBlockTimestamp() internal view virtual override returns (uint256) {
        return _mockTimestamp;
    }
}

// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IValueCapture {
    function totalCapturedUSD() external view returns (uint256);

    function lastCapturedBlock() external view returns (uint256);

    function getCapturedValue()
        external
        view
        returns (uint256 totalCapturedUSD_, uint256 lastCapturedBlock_);
}

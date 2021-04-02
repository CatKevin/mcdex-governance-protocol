// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IValueCapture {
    function totalCapturedUSD() external view returns (uint256);
}

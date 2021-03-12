// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract TestValueCapture {
    uint256 public capturedUSD;

    function setCapturedUSD(uint256 capturedUSD_) external {
        capturedUSD = capturedUSD_;
    }

    function increaseCapturedUSD(uint256 incremental) external {
        capturedUSD = capturedUSD + incremental;
    }

    function totalCapturedUSD() external view returns (uint256) {
        return capturedUSD;
    }
}

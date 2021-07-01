// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract MockValueCapture {
    uint256 public capturedUSD;
    uint256 public capturedBlock;

    address public minter;

    constructor(address minter_) {
        minter = minter_;
    }

    function setCapturedUSD(uint256 capturedUSD_, uint256 capturedBlock_) external {
        capturedUSD = capturedUSD_;
        capturedBlock = capturedBlock_;

        (bool success, bytes memory result) = minter.call(
            abi.encodeWithSignature("onValueCaptured(uint256,uint256)", capturedUSD, capturedBlock)
        );
        require(success, string(result));
    }

    function totalCapturedUSD() external view returns (uint256) {
        return capturedUSD;
    }

    function lastCapturedBlock() external view returns (uint256) {
        return capturedBlock;
    }

    function getCapturedValue()
        external
        view
        returns (uint256 totalCapturedUSD_, uint256 lastCapturedBlock_)
    {
        totalCapturedUSD_ = capturedUSD;
        lastCapturedBlock_ = capturedBlock;
    }
}

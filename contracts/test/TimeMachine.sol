// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract TimeMachine {
    bool public isOn;
    uint256 public mockBlockTime;
    uint256 public mockBlockNumber;

    function turnOn() public {
        isOn = true;
        mockBlockTime = block.timestamp;
        mockBlockNumber = block.number;
    }

    function turnOff() public {
        isOn = false;
    }

    function setBlockTime(uint256 time) public {
        mockBlockTime = time;
    }

    function skipTime(uint256 nSeconds) public {
        mockBlockTime = mockBlockTime + nSeconds;
    }

    function setBlockNumber(uint256 number) public {
        mockBlockNumber = number;
    }

    function skipBlock(uint256 number) public {
        mockBlockNumber = mockBlockNumber + number;
    }

    function blockTime() public view returns (uint256) {
        if (isOn) {
            return mockBlockTime;
        } else {
            return block.timestamp;
        }
    }

    function blockNumber() public view returns (uint256) {
        if (isOn) {
            return mockBlockNumber;
        } else {
            return block.number;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

contract MockDataExchange {
    bytes32 public constant TOTAL_CAPTURED_USD_KEY = keccak256("TOTAL_CAPTURED_USD_KEY");

    mapping(bytes32 => bytes) public dataValues;
    mapping(bytes32 => uint256) public dataUpdateTimestamps;

    function putData(
        bytes32 key,
        uint256 timestamp,
        bytes memory data
    ) public {
        dataValues[key] = data;
        dataUpdateTimestamps[key] = timestamp;
    }

    function isValidSource(bytes32 key, address account) public view returns (bool) {
        return true;
    }

    function getData(bytes32 key) public view returns (bytes memory, bool) {
        return (dataValues[key], dataUpdateTimestamps[key] > 0);
    }

    function getDataLastUpdateTimestamp(bytes32 key) public view returns (uint256) {
        return dataUpdateTimestamps[key];
    }

    function feedDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external {
        putData(key, block.timestamp, data);
    }

    function tryFeedDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external returns (bool) {
        putData(key, block.timestamp, data);
        return true;
    }

    function feedDataFromL2(bytes32 key, bytes calldata data) external {
        putData(key, block.timestamp, data);
    }

    function tryFeedDataFromL2(bytes32 key, bytes calldata data) external returns (bool) {
        putData(key, block.timestamp, data);
        return true;
    }

    function setTotalCapturedUSD(uint256 amount, uint256 blockNumber) public returns (uint256) {
        putData(TOTAL_CAPTURED_USD_KEY, block.timestamp, abi.encode(amount, blockNumber));
    }

    function getTotalCapturedUSD() public view returns (uint256) {
        (uint256 capturedValue, ) =
            abi.decode(dataValues[TOTAL_CAPTURED_USD_KEY], (uint256, uint256));
        return capturedValue;
    }
}

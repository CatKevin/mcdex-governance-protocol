// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IDataExchange {
    function getData(bytes32 key) external view returns (bytes memory, bool);

    function getDataLastUpdateTimestamp(bytes32 key) external view returns (uint256);

    function feedDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external;

    function tryFeedDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external returns (bool);

    function feedDataFromL2(bytes32 key, bytes calldata data) external;

    function tryFeedDataFromL2(bytes32 key, bytes calldata data) external returns (bool);
}

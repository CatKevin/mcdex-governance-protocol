// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IDataExchange {
    function getData(bytes32 key) external view returns (bytes memory, uint256);

    function pushDataFromL1(
        bytes32 key,
        bytes calldata data,
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external;

    function pushDataFromL2(bytes32 key, bytes calldata data) external;
}

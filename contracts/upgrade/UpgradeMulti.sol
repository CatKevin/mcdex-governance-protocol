// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract UpgradeV1 {
    uint256 public a;
    address public b;
    mapping(address => uint256) public c;
}

contract UpgradeV2 {
    uint256 public a;
    address public b;
    mapping(address => uint256) public c;

    uint256 public d;
}

struct Data {
    uint256 field1;
    address field2;
    bool field3;
}

struct Data2 {
    Data date1;
    Data[] data2;
}

contract Base {
    address public owner;
    bytes32[50] private __gap;
}

contract UpgradeV3 is Base {
    uint256 public a;
    address public b;
    mapping(address => uint256) public c;
    uint256 public d;
    Data public e;
    Data[] public f;
    uint256[] public g;
    uint256[10] public h;
    Data[12] public i;

    mapping(address => uint256) public j;
    mapping(address => Data) public k;

    uint256 public constant l = 999;

    Data2 public m;
    Data2[] public n;
    mapping(uint256 => Data2) public o;
}

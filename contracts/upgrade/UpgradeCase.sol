// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

contract UpgradeBefore {
    uint256 public a;
    address public b;
    address[1] public c;
}

contract UpgradeAfter {
    uint256 public a;
    address public b;
    address[2] public c;
}

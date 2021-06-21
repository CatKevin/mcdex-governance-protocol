// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

contract Context {
    function _blockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    bytes32[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";

import "./SafeMathExt.sol";

library Utils {
    using SafeMathExt for int256;
    using SignedSafeMathUpgradeable for int256;

    function hasTheSameSign(int256 x, int256 y) internal pure returns (bool) {
        if (x == 0 || y == 0) {
            return true;
        }
        return (x ^ y) >> 255 == 0;
    }

    function extractSign(int256 x) internal pure returns (int256) {
        return x >= 0 ? int256(1) : int256(-1);
    }

    function splitAmount(int256 amount, int256 delta) internal pure returns (int256, int256) {
        if (Utils.hasTheSameSign(amount, delta)) {
            return (0, delta);
        } else if (amount.abs() >= delta.abs()) {
            return (delta, 0);
        } else {
            return (amount.neg(), amount.add(delta));
        }
    }

    function isOpen(int256 amount, int256 delta) internal pure returns (bool) {
        return Utils.hasTheSameSign(amount, delta) || amount.abs() < delta.abs();
    }

    function chainID() internal pure returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }
}

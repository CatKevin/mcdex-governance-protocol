// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "hardhat/console.sol";

contract MockLiquidityPool {
    function forceToSetEmergencyState(uint256 perpetualIndex, int256 settlementPrice) external {
        console.log(
            "MockLiquidityPool :: forceToSetEmergencyState(%s, %s) called",
            perpetualIndex,
            uint256(settlementPrice)
        );
    }

    function setOperator(address newOperator) external {
        console.log("MockLiquidityPool :: setOperator(%s) called", newOperator);
    }

    function setFastCreationEnabled(bool enabled) external {
        console.log("MockLiquidityPool :: setFastCreationEnabled(%s) called", enabled ? 1 : 0);
    }
}

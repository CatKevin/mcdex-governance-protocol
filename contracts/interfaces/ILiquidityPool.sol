// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

interface ILiquidityPool {
    function checkIn() external;

    function transferOperator(address newOperator) external;

    function claimOperator() external;

    function revokeOperator() external;

    function setLiquidityPoolParameter(int256[2] calldata params) external;

    function setOracle(uint256 perpetualIndex, address oracle) external;

    function setPerpetualBaseParameter(uint256 perpetualIndex, int256[9] calldata baseParams)
        external;

    function setPerpetualRiskParameter(
        uint256 perpetualIndex,
        int256[8] calldata riskParams,
        int256[8] calldata minRiskParamValues,
        int256[8] calldata maxRiskParamValues
    ) external;

    function updatePerpetualRiskParameter(uint256 perpetualIndex, int256[8] calldata riskParams)
        external;

    function addAMMKeeper(uint256 perpetualIndex, address keeper) external;

    function removeAMMKeeper(uint256 perpetualIndex, address keeper) external;

    function createPerpetual(
        address oracle,
        int256[9] calldata baseParams,
        int256[8] calldata riskParams,
        int256[8] calldata minRiskParamValues,
        int256[8] calldata maxRiskParamValues
    ) external;

    function runLiquidityPool() external;
}

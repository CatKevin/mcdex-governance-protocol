// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ITWAPOracle {
    function priceTWAP() external view returns (uint256);
}

interface IUSDConvertor {
    function tokenIn() external view returns (address);

    function tokenOut() external view returns (address);

    function convert(uint256 amountIn) external returns (uint256 amountOut);
}

struct TokenEntry {
    ITWAPOracle oracle;
    IUSDConvertor convertor;
    uint256 slippageTolerance;
    uint256 cumulativeConvertedAmount;
}

library TokenConversion {
    using SafeMathUpgradeable for uint256;

    function convert(TokenEntry storage entry, uint256 amountIn) internal returns (uint256) {
        IERC20Upgradeable tokenIn = IERC20Upgradeable(entry.convertor.tokenIn());

        tokenIn.approve(address(entry.convertor), amountIn);
        uint256 amountOut = entry.convertor.convert(amountIn);
        uint256 realPrice = amountOut.mul(1e18).div(amountIn);
        uint256 referencePrice = entry.oracle.priceTWAP();
        require(referencePrice != 0, "reference price from oracle is zero");
        if (realPrice < referencePrice) {
            uint256 slippage = (referencePrice - realPrice).mul(1e18) / referencePrice;
            require(slippage <= entry.slippageTolerance, "slippage exceeds tolerance");
        }
        entry.cumulativeConvertedAmount = entry.cumulativeConvertedAmount.add(amountOut);
        return amountOut;
    }
}

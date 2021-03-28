// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "hardhat/console.sol";

interface ITWAPOracle {
    function priceTWAP() external view returns (uint256);
}

interface IUSDConvertor {
    function tokenIn() external view returns (address);

    function tokenOut() external view returns (address);

    function convert(uint256 amountIn)
        external
        returns (uint256 normalizedPrice, uint256 amountOut);
}

struct TokenEntry {
    address oracle;
    address convertor;
    uint256 slippageTolerance;
    uint256 cumulativeConvertedAmount;
}

library TokenConversion {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    function update(
        TokenEntry storage entry,
        address oracle,
        address convertor,
        uint256 slippageTolerance
    ) internal {
        require(oracle.isContract(), "convertor must be a contract");
        require(convertor.isContract(), "convertor must be a contract");
        require(slippageTolerance <= 1e18, "slippage tolerance is out of range");
        entry.convertor = convertor;
        entry.oracle = oracle;
        entry.slippageTolerance = slippageTolerance;
    }

    function isAvailable(TokenEntry storage entry) internal returns (bool) {
        return entry.oracle != address(0) && entry.convertor != address(0);
    }

    function tokenIn(TokenEntry storage entry) internal view returns (address) {
        return IUSDConvertor(entry.convertor).tokenIn();
    }

    function tokenOut(TokenEntry storage entry) internal view returns (address) {
        return IUSDConvertor(entry.convertor).tokenOut();
    }

    function convert(TokenEntry storage entry, uint256 amountIn) internal returns (uint256) {
        IUSDConvertor convertor = IUSDConvertor(entry.convertor);
        IERC20Upgradeable tokenIn = IERC20Upgradeable(convertor.tokenIn());

        tokenIn.approve(entry.convertor, amountIn);
        (uint256 dealPrice, uint256 amountOut) = convertor.convert(amountIn);
        uint256 referencePrice = ITWAPOracle(entry.oracle).priceTWAP(); // 1e18
        require(referencePrice != 0, "reference price from oracle is zero");
        if (dealPrice < referencePrice) {
            uint256 slippage = (referencePrice - dealPrice).mul(1e18) / referencePrice;
            require(slippage <= entry.slippageTolerance, "slippage exceeds tolerance");
        }
        entry.cumulativeConvertedAmount = entry.cumulativeConvertedAmount.add(amountOut);
        return amountOut;
    }
}

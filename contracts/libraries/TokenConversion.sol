// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/IUSDConvertor.sol";
import "../interfaces/ITWAPOracle.sol";

struct TokenEntry {
    address oracle;
    address convertor;
    uint256 slippageTolerance;
    uint256 cumulativeConvertedAmount;
}

/**
 * @dev TokenConversion is a wrapper to a external token exchange / swap.
 */
library TokenConversion {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    /**
     * @dev  Update a token entry, set properties.
     * @param   oracle              The address of oracle to retrieve reference price.
     * @param   convertor           An wrapper of external exchange / swap interface.
     * @param   slippageTolerance   The maximum acceptable price loss relative to the reference price in a conversion transaction.
     */
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

    /**
     * @dev  Test if a entry is available.
     */
    function isAvailable(TokenEntry storage entry) internal view returns (bool) {
        return entry.oracle != address(0) && entry.convertor != address(0);
    }

    /**
     * @dev The address of token to be converted.
     */
    function tokenIn(TokenEntry storage entry) internal view returns (address) {
        return IUSDConvertor(entry.convertor).tokenIn();
    }

    /**
     * @dev The address of token to get.
     */
    function tokenOut(TokenEntry storage entry) internal view returns (address) {
        return IUSDConvertor(entry.convertor).tokenOut();
    }

    /**
     * @dev Convert (including but not only sell) one token to another with an external exchange.
     *      The price slippage will be checked to prevent unexpected conversion.
     */
    function convert(TokenEntry storage entry, uint256 amountIn) internal returns (uint256) {
        IUSDConvertor convertor = IUSDConvertor(entry.convertor);
        IERC20Upgradeable(convertor.tokenIn()).approve(entry.convertor, amountIn);
        (uint256 dealPrice, uint256 amountOut) = convertor.exchange(amountIn);
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

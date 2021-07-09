// SPDX-License-Identifier: GPL
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/Path.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { IUSDConvertor } from "../interfaces/IUSDConvertor.sol";

contract UniV3Wrapper is IUSDConvertor {
    ISwapRouter public constant uniswapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    bytes public path;
    address public factory;

    function initialize(bytes memory path_) external {
        require(path.length == 0, "already initialized");
        path = path_;
        factory = msg.sender;
    }

    function tokenIn() public view override returns (address) {
        (address tokenA, , ) = Path.decodeFirstPool(path);
        return tokenA;
    }

    function tokenOut() public view override returns (address) {
        bytes memory i = path;
        while (Path.hasMultiplePools(i)) {
            i = Path.skipToken(i);
        }
        (, address tokenB, ) = Path.decodeFirstPool(i);
        return tokenB;
    }

    function setPath(bytes memory path_) external {
        require(msg.sender == factory, "sender must be factory");
        path = path_;
    }

    function exchangeForUSD(uint256 amountIn) external override returns (uint256 amountOut) {
        SafeERC20.safeTransferFrom(IERC20(tokenIn()), msg.sender, address(this), amountIn);
        SafeERC20.safeApprove(IERC20(tokenIn()), address(uniswapRouter), amountIn);
        amountOut = uniswapRouter.exactInput(
            ISwapRouter.ExactInputParams(
                path,
                msg.sender, // recipient
                block.timestamp + 15, // deadline
                amountIn,
                0 // amountOutMinimum
            )
        );
        require(amountOut > 0, "amountOut is zero");
    }
}

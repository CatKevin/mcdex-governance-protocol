// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "hardhat/console.sol";

interface IUSDConvertor {
    function tokenIn() external view returns (address token);

    function tokenOut() external view returns (address token);

    function covertToUSD(uint256 tokenAmount) external returns (uint256 usdAmount);
}

interface IDecimals {
    function decimals() external view returns (uint8);
}

struct USDTokenInfo {
    uint256 scaler;
    uint256 cumulativeCapturedBalance;
    IUSDConvertor converter;
}

contract ValueCapture {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant SYSTEM_DECIMALS = 18;

    address internal _dao;
    address internal _vault;
    uint256 internal _totalCapturedUSD;

    EnumerableSet.AddressSet internal _usdTokens;
    mapping(address => USDTokenInfo) internal _usdTokenInfos;

    event AddUSDToken(address tokenAddresss);
    event RemoveUSDToken(address tokenAddresss);
    event SetUSDConverter(address tokenAddress, address converter);
    event ConvertToUSD(address tokenIn, uint256 balanceIn, address tokenOut, uint256 balanceOut);
    event TranferToVault(address tokenAddress, uint256 amount);

    modifier onlyDAO() {
        require(msg.sender == _dao, "sender must be dao");
        _;
    }

    constructor(address vault, address dao) {
        _vault = vault;
        _dao = dao;
    }

    function getDAO() public view returns (address) {
        return _dao;
    }

    function getVault() public view returns (address) {
        return _vault;
    }

    function getCapturedUSD() public view returns (uint256) {
        return _totalCapturedUSD;
    }

    function getUSDTokenCount() public view returns (uint256) {
        return _usdTokens.length();
    }

    function getUSDToken(uint256 index) public view returns (address) {
        return _usdTokens.at(index);
    }

    function getAllUSDTokens() public view returns (address[] memory) {
        uint256 tokenCount = _usdTokens.length();
        address[] memory results = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            results[i] = _usdTokens.at(i);
        }
        return results;
    }

    function getUSDTokenInfo(address token)
        public
        view
        returns (
            uint256,
            uint256,
            address
        )
    {
        USDTokenInfo storage info = _usdTokenInfos[token];
        return (info.scaler, info.cumulativeCapturedBalance, address(info.converter));
    }

    function setUSDToken(address token, uint256 decimals) public onlyDAO {
        require(token.isContract(), "token address must be contract");
        require(!_usdTokens.contains(token), "token already in usd list");
        require(decimals >= 0 && decimals <= 18, "decimals out of range");

        try IDecimals(token).decimals() returns (uint8 actualDecimals) {
            require(actualDecimals == decimals, "decimals not match");
        } catch {}

        bool isAdded = _usdTokens.add(token);
        require(isAdded, "fail to add token to list");

        uint256 factor = 10**(SYSTEM_DECIMALS.sub(decimals));
        _usdTokenInfos[token].scaler = (factor == 0 ? 1 : factor);

        emit AddUSDToken(token);
    }

    function unsetUSDToken(address token) public onlyDAO {
        require(_usdTokens.contains(token), "token not in usd list");

        bool isRemoved = _usdTokens.remove(token);
        require(isRemoved, "fail to remove token from list");
        // leave _usdTokenInfos unremoved

        emit RemoveUSDToken(token);
    }

    function setUSDConverter(address token, address converter) public onlyDAO {
        require(converter.isContract(), "converter must be contract");
        address tokenOut = IUSDConvertor(converter).tokenOut();
        require(_usdTokens.contains(tokenOut), "token out not in list");

        _usdTokenInfos[token].converter = IUSDConvertor(converter);

        emit SetUSDConverter(token, converter);
    }

    function sendERC20(
        address token,
        address to,
        uint256 amount
    ) public onlyDAO {
        IERC20(token).safeTransfer(to, amount);
    }

    function sendERC721(
        address token,
        address to,
        uint256 tokenID
    ) public onlyDAO {
        IERC721(token).safeTransferFrom(address(this), to, tokenID);
    }

    function sendNativeToken(address to, uint256 amount) public onlyDAO {
        Address.sendValue(payable(to), amount);
    }

    function collectToken(address token) public {
        require(_vault != address(0), "vault is not set");

        (address tokenOut, uint256 balanceOut) = _convertTokenToUSD(token);

        require(balanceOut != 0, "invalid out balance");
        require(_usdTokens.contains(tokenOut), "unexpected out token");

        USDTokenInfo storage info = _usdTokenInfos[tokenOut];
        uint256 normalizeOutBalance = balanceOut.mul(info.scaler);
        _totalCapturedUSD = _totalCapturedUSD.add(normalizeOutBalance);
        info.cumulativeCapturedBalance = info.cumulativeCapturedBalance.add(normalizeOutBalance);
        IERC20(tokenOut).safeTransfer(_vault, balanceOut);

        emit TranferToVault(tokenOut, balanceOut);
    }

    function _convertTokenToUSD(address tokenIn)
        internal
        returns (address tokenOut, uint256 balanceOut)
    {
        uint256 balanceIn = IERC20(tokenIn).balanceOf(address(this));
        if (balanceIn == 0) {
            tokenOut = address(0);
            balanceOut = 0;
        } else if (_usdTokens.contains(tokenIn)) {
            tokenOut = tokenIn;
            balanceOut = balanceIn;
        } else {
            IUSDConvertor converter = _usdTokenInfos[tokenIn].converter;
            require(address(converter) != address(0), "token has no converter");
            tokenOut = converter.tokenOut();
            require(_usdTokens.contains(tokenOut), "converted usd not in list");
            uint256 prevBalance = IERC20(tokenOut).balanceOf(address(this));
            {
                console.log("[DEBUG] balanceIn", balanceIn);
                IERC20(tokenIn).approve(address(converter), balanceIn);
                balanceOut = converter.covertToUSD(balanceIn);
                console.log("[DEBUG] balanceOut", balanceOut);

                require(balanceOut > 0, "balance out is 0");
            }
            uint256 postBalance = IERC20(tokenOut).balanceOf(address(this));

            require(postBalance.sub(prevBalance) == balanceOut, "converted balance not match");
        }
        emit ConvertToUSD(tokenIn, balanceIn, tokenOut, balanceOut);
    }
}

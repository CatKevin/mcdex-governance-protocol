// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

interface IUSDConvertor {
    function usdToken() external view returns (address tokenAddress);

    function covertToUSD(uint256 tokenAmount) external returns (uint256 usdAmount);
}

contract ValueCapture {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal _dao;
    address internal _vault;
    uint256 internal _capturedUSD;
    EnumerableSet.AddressSet internal _usdTokens;
    mapping(address => address) internal _usdConverters;

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
        return _capturedUSD;
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

    function getConverter(address token) public view returns (address) {
        return _usdConverters[token];
    }

    function setUSDToken(address token) public onlyDAO {
        require(!_usdTokens.contains(token), "token already in usd list");
        require(token.isContract(), "token address must be contract");
        bool isAdded = _usdTokens.add(token);
        require(isAdded, "fail to add token to list");
        emit AddUSDToken(token);
    }

    function unsetUSDToken(address token) public onlyDAO {
        require(_usdTokens.contains(token), "token not in usd list");
        bool isRemoved = _usdTokens.remove(token);
        require(isRemoved, "fail to remove token from list");
        emit RemoveUSDToken(token);
    }

    function setUSDConverter(address token, address converter) public onlyDAO {
        address usdToken = IUSDConvertor(converter).usdToken();
        require(_usdTokens.contains(usdToken), "converted usd not in list");
        _usdConverters[token] = converter;
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
        require(token.isContract(), "token address must be contract");
        require(_vault != address(0), "vault is not set");

        (address tokenOut, uint256 balanceOut) = _convertTokenToUSD(token);
        require(tokenOut != address(0) && balanceOut != 0, "invalid converted output");
        _capturedUSD = _capturedUSD.add(balanceOut);
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
            address converter = _usdConverters[tokenIn];
            tokenOut = IUSDConvertor(converter).usdToken();
            require(_usdTokens.contains(tokenOut), "converted usd not in list");
            require(converter != address(0), "token has no converter");

            uint256 prevBalance = IERC20(tokenOut).balanceOf(address(this));
            {
                IERC20(tokenIn).approve(converter, balanceIn);
                balanceOut = IUSDConvertor(converter).covertToUSD(balanceIn);
                require(balanceOut > 0, "invalid return amount");
            }
            uint256 postBalance = IERC20(tokenOut).balanceOf(address(this));
            require(postBalance.sub(prevBalance) == balanceOut, "converted balance not match");
        }
        emit ConvertToUSD(tokenIn, balanceIn, tokenOut, balanceOut);
    }
}

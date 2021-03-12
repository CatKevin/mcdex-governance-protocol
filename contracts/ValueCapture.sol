// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

// import "./libraries/SafeOwnable.sol";
import "./interfaces/IUSDConvertor.sol";

import "hardhat/console.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

struct USDTokenInfo {
    uint256 scaler;
    uint256 cumulativeCapturedBalance;
}

contract ValueCapture is Initializable, ContextUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    uint256 private constant SYSTEM_DECIMALS = 18;

    address public vault;
    address public guardian;
    uint256 public totalCapturedUSD;

    EnumerableSetUpgradeable.AddressSet internal _usdTokens;
    mapping(address => USDTokenInfo) internal _usdTokenInfos;
    mapping(address => IUSDConvertor) internal _usdTokenConverters;

    event AddUSDToken(address indexed tokenAddresss);
    event RemoveUSDToken(address indexed tokenAddresss);
    event SetUSDConverter(address indexed tokenAddress, address indexed converter);
    event ConvertToUSD(
        address indexed tokenIn,
        uint256 balanceIn,
        address indexed tokenOut,
        uint256 balanceOut
    );
    event TranferToVault(address indexed tokenAddress, uint256 amount);
    event SetGuardian(address indexed previousGuardian, address indexed newGuardian);

    modifier onlyGuardian() {
        require(_msgSender() == guardian, "caller must be guardian");
        _;
    }

    receive() external payable {}

    /**
     * @notice  Initialzie value capture contract.
     *
     * @param   vault_  The address of vault contract. All funds later will be collected to this address.
     * @param   owner_  The address of owner. Owner has privilege to set guardian of value capture which is able to call
     *                  collect functions.
     */
    function initialize(address vault_, address owner_) external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        vault = vault_;
        transferOwnership(owner_);
    }

    /**
     * @notice  Get total count of USD token in whitelist.
     */
    function getUSDTokenCount() public view returns (uint256) {
        return _usdTokens.length();
    }

    /**
     * @notice  Get address of USD token in whitelist by index.
     *
     * @param   index   The index of USD token address to retrieve.
     */
    function getUSDToken(uint256 index) public view returns (address) {
        return _usdTokens.at(index);
    }

    /**
     * @notice  Return all addresses of USD tokens in whitelist as an array.
     */
    function getAllUSDTokens() public view returns (address[] memory) {
        uint256 tokenCount = _usdTokens.length();
        address[] memory results = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            results[i] = _usdTokens.at(i);
        }
        return results;
    }

    /**
     * @notice  Get scaler and cumulative captured balance of usd token.
     *          Removing a USD token will not clean its existing data.
     *
     * @param   token   The address of USD token.
     */
    function getUSDTokenInfo(address token) public view returns (uint256, uint256) {
        USDTokenInfo storage info = _usdTokenInfos[token];
        return (info.scaler, info.cumulativeCapturedBalance);
    }

    /**
     * @notice  Set guardian of value capture contract.
     *          The guaridan is able to call method to sell tokens for USD.
     *
     * @param   newGuardian The address of new guardian.
     */
    function setGuardian(address newGuardian) public onlyOwner {
        require(newGuardian != guardian, "new guardian is already guardian");
        emit SetGuardian(guardian, newGuardian);
        guardian = newGuardian;
    }

    /**
     * @notice  Add a USD token to whitelist.
     *          Since not all the ERC20 has decimals interface, caller needs to specify the decimal of USD token.
     *          But the `decimals()` of token will be checked to match the parameter passed in if possible.
     *
     * @param   token       The address of usd token to be put into whitelist.
     * @param   decimals    The decimals of token.
     */
    function setUSDToken(address token, uint256 decimals) public onlyOwner {
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

    /**
     * @notice  Remove a USD token from whitelist.
     *
     * @param   token   The address of USD token to remove.
     */
    function unsetUSDToken(address token) public onlyOwner {
        require(_usdTokens.contains(token), "token not in usd list");

        bool isRemoved = _usdTokens.remove(token);
        require(isRemoved, "fail to remove token from list");
        // leave _usdTokenInfos unremoved

        emit RemoveUSDToken(token);
    }

    /**
     * @notice  Add a 'converter' for some token.
     *          A converter is known as a external contract who has an interface to accept some kind of token
     *          and return USD token in value capture's whitelist.
     *          That means the output token of converter must be in the whitelist.
     *          See contract/interfaces/IUSDConvertor.sol for interface spec of a converter.
     *
     * @param   token       The address of any token accepted by converter.
     * @param   converter   The address of converter contract.
     */
    function setUSDConverter(address token, address converter) public onlyOwner {
        require(converter.isContract(), "converter must be contract");
        IUSDConvertor convertor = IUSDConvertor(converter);
        require(_usdTokens.contains(convertor.tokenOut()), "token out not in list");
        _usdTokenConverters[token] = IUSDConvertor(converter);

        emit SetUSDConverter(token, converter);
    }

    function collectToken(address token) public onlyGuardian {
        require(vault != address(0), "vault is not set");

        (address tokenOut, uint256 balanceOut) = _convertTokenToUSD(token);
        require(_usdTokens.contains(tokenOut), "unexpected out token");

        USDTokenInfo storage info = _usdTokenInfos[tokenOut];
        uint256 normalizeOutBalance = balanceOut.mul(info.scaler);
        totalCapturedUSD = totalCapturedUSD.add(normalizeOutBalance);
        info.cumulativeCapturedBalance = info.cumulativeCapturedBalance.add(normalizeOutBalance);
        IERC20Upgradeable(tokenOut).safeTransfer(vault, balanceOut);

        emit TranferToVault(tokenOut, balanceOut);
    }

    /**
     * @notice  This method is should not be called if there are any converter available for given ERC20 token.
     *          But if there is really not, or the converter is lack of enough liquidity,
     *          guardian will be able to send the asset to vault for other usage.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function collectERC20Token(address token, uint256 amount) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        IERC20Upgradeable(token).safeTransfer(vault, amount);
    }

    /**
     * @notice  This method has the same usage as `collectERC20Token`.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function collectERC721Token(address token, uint256 tokenID) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        IERC721Upgradeable(token).safeTransferFrom(address(this), vault, tokenID);
    }

    /**
     * @notice  This method has the same usage as `collectERC20Token`.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function collectNativeCurrency(uint256 amount) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        AddressUpgradeable.sendValue(payable(vault), amount);
        console.log("DEBUG enter collectNativeCurrency", amount);
    }

    function _convertTokenToUSD(address tokenIn)
        internal
        returns (address tokenOut, uint256 balanceOut)
    {
        uint256 balanceIn = IERC20Upgradeable(tokenIn).balanceOf(address(this));
        if (balanceIn == 0) {
            // early revert
            revert("no balance to convert");
        } else if (_usdTokens.contains(tokenIn)) {
            // if the token to be converted is USD token in whitelist
            // directly return the input amount
            tokenOut = tokenIn;
            balanceOut = balanceIn;
        } else {
            IUSDConvertor converter = _usdTokenConverters[tokenIn];
            require(address(converter) != address(0), "token has no converter");
            tokenOut = converter.tokenOut();
            require(_usdTokens.contains(tokenOut), "converted usd not in list");
            // not necessary, but double check to prevent unexpected nested call.
            uint256 prevBalance = IERC20Upgradeable(tokenOut).balanceOf(address(this));
            {
                IERC20Upgradeable(tokenIn).approve(address(converter), balanceIn);
                balanceOut = converter.covertToUSD(balanceIn);
            }
            uint256 postBalance = IERC20Upgradeable(tokenOut).balanceOf(address(this));
            require(postBalance.sub(prevBalance) == balanceOut, "converted balance not match");
        }
        require(balanceOut > 0, "balance out is 0");
        emit ConvertToUSD(tokenIn, balanceIn, tokenOut, balanceOut);
    }
}

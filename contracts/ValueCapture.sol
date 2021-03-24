// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./libraries/TokenConversion.sol";
import "./Guardianship.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

contract ValueCapture is Initializable, Guardianship {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using TokenConversion for TokenEntry;

    uint256 public constant SYSTEM_DECIMALS = 18;

    address public vault;
    uint256 public totalCapturedUSD;
    mapping(address => TokenEntry) public assetEntries;

    EnumerableSetUpgradeable.AddressSet internal _usdTokenList;
    mapping(address => uint256) internal _normalizer;

    event AddUSDToken(address indexed usdToken);
    event RemoveUSDToken(address indexed usdToken);
    event SetConvertor(address indexed tokenAddress, address indexed convertor);
    event ConvertToken(
        address indexed tokenIn,
        uint256 balanceIn,
        address indexed tokenOut,
        uint256 balanceOut
    );
    event ForwardAsset(address indexed tokenOut, uint256 amountOut, uint256 normalizeAmountOut);
    event ForwardERC20Token(address indexed tokenOut, uint256 amount);
    event ForwardERC721Token(address indexed tokenOut, uint256 tokenID);
    event ForwardNativeValue(uint256 amount);

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

        vault = vault_;
        transferOwnership(owner_);
        transferGuardianship(owner_);
    }

    /**
     * @notice  Return all addresses of USD tokens in whitelist as an array.
     */
    function getUSDTokens() public view returns (address[] memory) {
        uint256 tokenCount = _usdTokenList.length();
        address[] memory results = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            results[i] = _usdTokenList.at(i);
        }
        return results;
    }

    /**
     * @notice  Add a USD token to whitelist.
     *          Since not all the ERC20 has decimals interface, caller needs to specify the decimal of USD token.
     *          But the `decimals()` of token will be checked to match the parameter passed in if possible.
     *
     * @param   token       The address of usd token to be put into whitelist.
     * @param   decimals    The decimals of token.
     */
    function addUSDToken(address token, uint256 decimals) public onlyOwner {
        require(!_usdTokenList.contains(token), "token already in usd list");
        require(token.isContract(), "token address must be contract");
        require(decimals >= 0 && decimals <= 18, "decimals out of range");
        // verify decimals if possible
        try IDecimals(token).decimals() returns (uint8 actualDecimals) {
            require(actualDecimals == decimals, "decimals not match");
        } catch {}

        bool isAdded = _usdTokenList.add(token);
        require(isAdded, "fail to add token to list");

        uint256 normalizer = 10**(SYSTEM_DECIMALS.sub(decimals));
        _normalizer[token] = normalizer;

        emit AddUSDToken(token);
    }

    /**
     * @notice  Remove a USD token from whitelist.
     *
     * @param   token   The address of USD token to remove.
     */
    function removeUSDToken(address token) public onlyOwner {
        require(_usdTokenList.contains(token), "token not in usd list");

        bool isRemoved = _usdTokenList.remove(token);
        require(isRemoved, "fail to remove token from list");

        emit RemoveUSDToken(token);
    }

    /**
     * @notice  Add a 'convertor' for some token.
     *          A convertor is known as a external contract who has an interface to accept some kind of token
     *          and return USD token in value capture's whitelist.
     *          That means the output token of convertor must be in the whitelist.
     *          See contract/interfaces/IUSDConvertor.sol for interface spec of a convertor.
     *
     * @param   token               The address of any token accepted by convertor.
     * @param   oracle              The address of oracle to read reference token price in USD.
     * @param   convertor_          The address of convertor contract.
     * @param   slippageTolerance   The max slippage can be accepted when convert token to USD, 100% = 1e18;
     */
    function setConvertor(
        address token,
        address oracle,
        address convertor_,
        uint256 slippageTolerance
    ) public onlyOwner {
        require(slippageTolerance <= 1e18, "slippage tolerance is out of range");
        require(convertor_.isContract(), "convertor must be contract");

        IUSDConvertor convertor = IUSDConvertor(convertor_);
        require(_usdTokenList.contains(convertor.tokenOut()), "token out is not in usd list");
        // set or update, leave cum amount unchanged
        assetEntries[token] = TokenEntry({
            oracle: ITWAPOracle(oracle),
            convertor: convertor,
            slippageTolerance: slippageTolerance,
            cumulativeConvertedAmount: assetEntries[token].cumulativeConvertedAmount
        });

        emit SetConvertor(token, convertor_);
    }

    function forwardAsset(address token) public onlyGuardian {
        require(vault != address(0), "vault is not set");

        (address tokenOut, uint256 amountOut) = _convertTokenToUSD(token);
        require(_usdTokenList.contains(tokenOut), "unexpected out token");

        uint256 normalizer = _normalizer[token];
        require(normalizer != 0, "unexpected normalizer");
        uint256 normalizeAmountOut = amountOut.mul(normalizer);
        totalCapturedUSD = totalCapturedUSD.add(normalizeAmountOut);
        IERC20Upgradeable(tokenOut).safeTransfer(vault, amountOut);

        emit ForwardAsset(tokenOut, amountOut, normalizeAmountOut);
    }

    /**
     * @notice  This method is should not be called if there are any convertor available for given ERC20 token.
     *          But if there is really not, or the convertor is lack of enough liquidity,
     *          guardian will be able to send the asset to vault for other usage.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function forwardERC20Token(address token, uint256 amount) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        IERC20Upgradeable(token).safeTransfer(vault, amount);
        emit ForwardERC20Token(token, amount);
    }

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function forwardERC721Token(address token, uint256 tokenID) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        IERC721Upgradeable(token).safeTransferFrom(address(this), vault, tokenID);
        emit ForwardERC721Token(token, tokenID);
    }

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          **Asset sent though this method to vault will not affect mintable amount of MCB.**
     */
    function forwardNativeCurrency(uint256 amount) public onlyGuardian {
        require(vault != address(0), "vault is not set");
        AddressUpgradeable.sendValue(payable(vault), amount);
        emit ForwardNativeValue(amount);
    }

    function _convertTokenToUSD(address tokenIn)
        internal
        returns (address tokenOut, uint256 amountOut)
    {
        uint256 amountIn = IERC20Upgradeable(tokenIn).balanceOf(address(this));
        if (amountIn == 0) {
            // early revert
            revert("no balance to convert");
        } else if (_usdTokenList.contains(tokenIn)) {
            // if the token to be converted is USD token in whitelist
            // directly return the input amount
            tokenOut = tokenIn;
            amountOut = amountIn;
        } else {
            IUSDConvertor convertor = assetEntries[tokenIn].convertor;
            require(address(convertor) != address(0), "token has no convertor");
            // not necessary, but double check to prevent unexpected nested call.
            amountOut = convertor.convert(amountIn);
        }
        require(amountOut > 0, "balance out is 0");
        emit ConvertToken(tokenIn, amountIn, tokenOut, amountOut);
    }
}

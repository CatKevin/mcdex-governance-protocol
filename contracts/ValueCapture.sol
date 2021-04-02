// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./libraries/TokenConversion.sol";
import "./interfaces/IAuthenticator.sol";
import "./interfaces/IDataExchange.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

contract ValueCapture is Initializable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using TokenConversion for TokenEntry;

    uint256 public constant SYSTEM_DECIMALS = 18;
    bytes32 public constant VALUE_CAPTURE_ADMIN_ROLE = keccak256("VALUE_CAPTURE_ADMIN_ROLE");
    bytes32 public constant TOTAL_CAPTURED_USD_KEY = keccak256("TOTAL_CAPTURED_USD_KEY");

    IAuthenticator public authenticator;
    IDataExchange public dataExchange;

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
    event ForwardETH(uint256 amount);
    event ForwardERC20Token(address indexed tokenOut, uint256 amount);
    event ForwardERC721Token(address indexed tokenOut, uint256 tokenID);

    receive() external payable {}

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(VALUE_CAPTURE_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    /**
     * @notice  Initialzie value capture contract.
     *
     * @param   authenticator_  The address of authenticator controller that can determine who is able to call
     *                          admin interfaces.
     * @param   vault_          The address of vault contract. All funds later will be collected to this address.
     */
    function initialize(
        address authenticator_,
        address dataExchange_,
        address vault_
    ) external initializer {
        require(vault_ != address(0), "vault is the zero address");
        require(authenticator_.isContract(), "authenticator must be a contract");

        __ReentrancyGuard_init();

        authenticator = IAuthenticator(authenticator_);
        dataExchange = IDataExchange(dataExchange_);
        vault = vault_;
    }

    /**
     * @notice  Return all addresses of USD tokens in whitelist as an array.
     */
    function listUSDTokens(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        require(end > begin, "begin should be lower than end");
        uint256 length = _usdTokenList.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = (end <= length) ? end : length;
        result = new address[](safeEnd - begin);
        for (uint256 i = begin; i < safeEnd; i++) {
            result[i - begin] = _usdTokenList.at(i);
        }
        return result;
    }

    /**
     * @notice  Add a USD token to whitelist.
     *          Since not all the ERC20 has decimals interface, caller needs to specify the decimal of USD token.
     *          But the `decimals()` of token will be checked to match the parameter passed in if possible.
     *
     * @param   token       The address of usd token to be put into whitelist.
     * @param   decimals    The decimals of token.
     */
    function addUSDToken(address token, uint256 decimals) public onlyAuthorized {
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
    function removeUSDToken(address token) public onlyAuthorized {
        require(_usdTokenList.contains(token), "token not in usd list");

        bool isRemoved = _usdTokenList.remove(token);
        require(isRemoved, "fail to remove token from list");

        emit RemoveUSDToken(token);
    }

    /**
     * @notice  Add a 'convertor' for some token.
     *          A convertor is known as a external contract who has an interface to accept some kind of token
     *          and return USD token in value capture's whitelist.
     *          That means the output token of convertor must be in th e whitelist.
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
    ) public onlyAuthorized {
        require(slippageTolerance <= 1e18, "slippage tolerance is out of range");
        require(oracle.isContract(), "oracle must be a contract");
        require(convertor_.isContract(), "convertor must be a contract");
        require(
            _usdTokenList.contains(IUSDConvertor(convertor_).tokenOut()),
            "token out is not in usd list"
        );
        assetEntries[token].update(oracle, convertor_, slippageTolerance);

        emit SetConvertor(token, convertor_);
    }

    /**
     * @notice  Exchange the all the given token stored in contract for USD token, then forward the USD token to vault.
     *
     * @param   token   The address of token to forward to vault.
     */
    function forwardAsset(address token, uint256 amountIn) external nonReentrant {
        require(vault != address(0), "vault is not set");
        require(amountIn != 0, "amount in is zero");

        // prepare token to be transfer to vault
        (address tokenOut, uint256 amountOut) = _convertTokenToUSD(token, amountIn);
        require(_usdTokenList.contains(tokenOut), "unexpected out token");

        // transfer token to vault && add up the conveted amount
        uint256 normalizer = _normalizer[tokenOut];
        require(normalizer != 0, "unexpected normalizer");
        uint256 normalizeAmountOut = amountOut.mul(normalizer);
        totalCapturedUSD = totalCapturedUSD.add(normalizeAmountOut);
        IERC20Upgradeable(tokenOut).safeTransfer(vault, amountOut);
        // ignore the result so that the sync won't stuck the foward procedure
        dataExchange.tryFeedDataFromL2(
            TOTAL_CAPTURED_USD_KEY,
            abi.encode(totalCapturedUSD, _getBlockNumber())
        );

        emit ForwardAsset(tokenOut, amountOut, normalizeAmountOut);
    }

    function feedCapturedValueToL1() external nonReentrant {
        bool succeeded =
            dataExchange.tryFeedDataFromL2(
                TOTAL_CAPTURED_USD_KEY,
                abi.encode(totalCapturedUSD, _getBlockNumber())
            );
        require(succeeded, "fail to feed captured value");
    }

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardETH(uint256 amount) external onlyAuthorized nonReentrant {
        require(vault != address(0), "vault is not set");
        AddressUpgradeable.sendValue(payable(vault), amount);
        emit ForwardETH(amount);
    }

    /**
     * @notice  This method is should not be called if there are any convertor available for given ERC20 token.
     *          But if there is really not, or the convertor is lack of enough liquidity,
     *          guardian will be able to send the asset to vault for other usage.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardERC20Token(address token, uint256 amount) external onlyAuthorized nonReentrant {
        require(vault != address(0), "vault is not set");
        IERC20Upgradeable(token).safeTransfer(vault, amount);
        emit ForwardERC20Token(token, amount);
    }

    /**
     * @notice  This method has the same usage as `forwardERC20Token`.
     *
     *          *Asset sent though this method to vault will not affect mintable amount of MCB.*
     */
    function forwardERC721Token(address token, uint256 tokenID)
        external
        onlyAuthorized
        nonReentrant
    {
        require(vault != address(0), "vault is not set");
        IERC721Upgradeable(token).safeTransferFrom(address(this), vault, tokenID);
        emit ForwardERC721Token(token, tokenID);
    }

    function _convertTokenToUSD(address tokenIn, uint256 amountIn)
        internal
        returns (address tokenOut, uint256 amountOut)
    {
        uint256 convertableAmount = IERC20Upgradeable(tokenIn).balanceOf(address(this));
        require(amountIn <= convertableAmount, "amount in execceds convertable amount");
        if (amountIn == 0) {
            // early revert
            revert("no balance to convert");
        } else if (_usdTokenList.contains(tokenIn)) {
            // if the token to be converted is USD token in whitelist, return the balance
            tokenOut = tokenIn;
            amountOut = amountIn;
        } else {
            require(assetEntries[tokenIn].isAvailable(), "token has no convertor");
            // not necessary, but double check to prevent unexpected nested call.
            tokenOut = assetEntries[tokenIn].tokenOut();
            amountOut = assetEntries[tokenIn].convert(amountIn);
        }
        require(amountOut > 0, "balance out is 0");
        emit ConvertToken(tokenIn, amountIn, tokenOut, amountOut);
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    bytes32[50] private __gap;
}

// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { ICaptureNotifyRecipient } from "./interfaces/ICaptureNotifyRecipient.sol";
import { IUSDConvertor } from "./interfaces/IUSDConvertor.sol";
import { IAuthenticator } from "./interfaces/IAuthenticator.sol";

interface IDecimals {
    function decimals() external view returns (uint8);
}

contract ValueCapture is Initializable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    uint256 public constant SYSTEM_DECIMALS = 18;
    bytes32 public constant VALUE_CAPTURE_ADMIN_ROLE = keccak256("VALUE_CAPTURE_ADMIN_ROLE");

    IAuthenticator public authenticator;
    address public vault;
    address public captureNotifyRecipient;
    uint256 public totalCapturedUSD;
    uint256 public lastCapturedBlock;

    EnumerableSetUpgradeable.AddressSet internal _usdTokenList;
    mapping(address => uint256) public normalizers;
    mapping(address => IUSDConvertor) public externalExchanges;

    event AddUSDToken(address indexed usdToken);
    event RemoveUSDToken(address indexed usdToken);
    event SetConvertor(address indexed tokenAddress, address indexed exchange);
    event ExchangeToken(
        address indexed tokenIn,
        uint256 balanceIn,
        address indexed tokenOut,
        uint256 balanceOut
    );
    event ForwardAsset(address indexed tokenOut, uint256 amountOut, uint256 normalizeAmountOut);
    event ForwardETH(uint256 amount);
    event ForwardERC20Token(address indexed tokenOut, uint256 amount);
    event ForwardERC721Token(address indexed tokenOut, uint256 tokenID);
    event SetMiner(address indexed oldMinter, address indexed newMinter);

    receive() external payable {}

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(VALUE_CAPTURE_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    function getCapturedValue() public view returns (uint256, uint256) {
        return (totalCapturedUSD, lastCapturedBlock);
    }

    /**
     * @notice  Initialzie value capture contract.
     *
     * @param   authenticator_  The address of authenticator controller that can determine who is able to call
     *                          admin interfaces.
     * @param   vault_          The address of vault contract. All funds later will be collected to this address.
     */
    function initialize(address authenticator_, address vault_) external initializer {
        require(vault_ != address(0), "vault is the zero address");
        require(authenticator_.isContract(), "authenticator must be a contract");

        __ReentrancyGuard_init();

        authenticator = IAuthenticator(authenticator_);
        vault = vault_;
    }

    function setCaptureNotifyRecipient(address newRecipient) external onlyAuthorized {
        require(newRecipient != captureNotifyRecipient, "newRecipient is already set");
        emit SetMiner(captureNotifyRecipient, newRecipient);
        captureNotifyRecipient = newRecipient;
    }

    /**
     * @notice  Return all addresses of USD tokens in whitelist as an array.
     */
    function listUSDTokens(uint256 begin, uint256 end)
        external
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
    function addUSDToken(address token, uint256 decimals) external onlyAuthorized {
        require(!_usdTokenList.contains(token), "token already in usd list");
        require(token.isContract(), "token address must be contract");
        require(decimals <= 18, "decimals out of range");
        // verify decimals if possible
        try IDecimals(token).decimals() returns (uint8 actualDecimals) {
            require(actualDecimals == decimals, "decimals not match");
        } catch {}

        bool isAdded = _usdTokenList.add(token);
        require(isAdded, "fail to add token to list");
        normalizers[token] = 10**(SYSTEM_DECIMALS.sub(decimals));

        emit AddUSDToken(token);
    }

    /**
     * @notice  Remove a USD token from whitelist.
     *
     * @param   token   The address of USD token to remove.
     */
    function removeUSDToken(address token) external onlyAuthorized {
        require(_usdTokenList.contains(token), "token not in usd list");

        bool isRemoved = _usdTokenList.remove(token);
        require(isRemoved, "fail to remove token from list");

        emit RemoveUSDToken(token);
    }

    /**
     * @notice  Add a 'exchange' for some token.
     *          A exchange is known as a external contract who has an interface to accept some kind of token
     *          and return USD token in value capture's whitelist.
     *          That means the output token of exchange must be in th e whitelist.
     *          See contract/interfaces/IUSDConvertor.sol for interface spec of a exchange.
     *
     * @param   token               The address of any token accepted by exchange.
     * @param   exchange_          The address of exchange contract.
     */
    function setExternalExchange(address token, address exchange_) external onlyAuthorized {
        require(exchange_.isContract(), "exchange must be a contract");
        IUSDConvertor exchange = IUSDConvertor(exchange_);
        require(token == exchange.tokenIn(), "input token mismatch");
        require(_usdTokenList.contains(exchange.tokenOut()), "token out is not in usd list");

        externalExchanges[token] = exchange;
        emit SetConvertor(token, exchange_);
    }

    // /**
    //  * @notice  Exchange the all the given token stored in contract for USD token, then forward the USD token to vault.
    //  *
    //  * @param   token       The address of token to forward to vault.
    //  * @param   amountIn    The amount to (exchange for USD and) forward to vault.
    //  */
    // function forwardAsset(address token, uint256 amountIn) external nonReentrant onlyAuthorized {
    //     _forwardAsset(token, amountIn);
    //     tryNotifyCapturedValue();
    // }

    /**
     * @notice  Batch version of forwardAsset.
     *
     * @param   tokens      The array of address of token to forward to vault.
     * @param   amountsIn   The array of amounts to (exchange for USD and) forward to vault.
     */
    function forwardMultiAssets(address[] memory tokens, uint256[] memory amountsIn)
        external
        nonReentrant
        onlyAuthorized
    {
        require(tokens.length == amountsIn.length, "length of parameters mismatch");
        for ((uint256 i, uint256 count) = (0, tokens.length); i < count; i++) {
            _forwardAsset(tokens[i], amountsIn[i]);
        }
        tryNotifyCapturedValue();
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
     * @notice  This method is should not be called if there are any exchange available for given ERC20 token.
     *          But if there is really not, or the exchange is lack of enough liquidity,
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

    function _forwardAsset(address token, uint256 amountIn) internal {
        require(vault != address(0), "vault is not set");
        require(amountIn != 0, "amount in is zero");

        // prepare token to be transfer to vault
        (address tokenOut, uint256 amountOut) = _exchangeTokenForUSD(token, amountIn);
        require(_usdTokenList.contains(tokenOut), "unexpected out token");

        // transfer token to vault && add up the converted amount
        uint256 normalizer = normalizers[tokenOut];
        require(normalizer != 0, "unexpected normalizer");

        uint256 normalizeAmountOut = amountOut.mul(normalizer);
        totalCapturedUSD = totalCapturedUSD.add(normalizeAmountOut);
        lastCapturedBlock = _getBlockNumber();

        IERC20Upgradeable(tokenOut).safeTransfer(vault, amountOut);

        emit ForwardAsset(tokenOut, amountOut, normalizeAmountOut);
    }

    function _exchangeTokenForUSD(address tokenIn, uint256 amountIn)
        internal
        returns (address tokenOut, uint256 amountOut)
    {
        uint256 tokenInBalance = IERC20Upgradeable(tokenIn).balanceOf(address(this));
        require(amountIn <= tokenInBalance, "amount in execceds convertable amount");
        if (amountIn == 0) {
            // early revert
            revert("no balance to convert");
        } else if (_usdTokenList.contains(tokenIn)) {
            // if the token to be converted is USD token in whitelist, return the balance
            tokenOut = tokenIn;
            amountOut = amountIn;
        } else {
            IUSDConvertor exchange = externalExchanges[tokenIn];
            require(address(exchange).isContract(), "token exchange is not available");
            require(tokenIn == exchange.tokenIn(), "input token mismatch");
            tokenOut = externalExchanges[tokenIn].tokenOut();

            IERC20Upgradeable(tokenIn).safeIncreaseAllowance(address(exchange), amountIn);
            amountOut = externalExchanges[tokenIn].exchangeForUSD(amountIn);
        }
        require(amountOut > 0, "balance out is 0");
        emit ExchangeToken(tokenIn, amountIn, tokenOut, amountOut);
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    function tryNotifyCapturedValue() public onlyAuthorized {
        if (!captureNotifyRecipient.isContract()) {
            return;
        }
        try
            ICaptureNotifyRecipient(captureNotifyRecipient).onValueCaptured(
                totalCapturedUSD,
                lastCapturedBlock
            )
        {} catch {}
    }

    bytes32[50] private __gap;
}

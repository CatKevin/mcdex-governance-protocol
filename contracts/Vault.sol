// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IAuthenticator.sol";

import "hardhat/console.sol";

/**
 * @notice  Vault is a contract to hold various assets from different source.
 */
contract Vault is Initializable, ERC721HolderUpgradeable, ReentrancyGuardUpgradeable {
    // using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant VAULT_ADMIN_ROLE = keccak256("VAULT_ADMIN_ROLE");

    IAuthenticator public authenticator;

    event TransferETH(address indexed to, uint256 amount);
    event TransferERC20Token(address indexed token, address indexed to, uint256 amount);
    event TransferERC721Token(address indexed token, uint256 tokenID, address indexed to);
    event ExecuteTransaction(address indexed to, bytes data, uint256 value);

    receive() external payable {}

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(VAULT_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    /**
     * @notice  Initialzie vault contract.
     *
     * @param   authenticator_  The address of authentication controller that can determine who is able to call
     *                          admin interfaces.
     */
    function initialize(address authenticator_) external initializer {
        require(authenticator_ != address(0), "authenticator is the zero address");

        __ReentrancyGuard_init();

        authenticator = IAuthenticator(authenticator_);
    }

    /**
     * @notice  A helper method to transfer Ether to somewhere.
     *
     * @param   recipient   The receiver of the sent asset.
     * @param   value       The amount of asset to send.
     */
    function transferETH(address recipient, uint256 value) external onlyAuthorized nonReentrant {
        require(value != 0, "transfer value is zero");
        AddressUpgradeable.sendValue(payable(recipient), value);
        emit TransferETH(recipient, value);
    }

    /**
     * @notice  A helper method to transfer ERC20 to somewhere.
     *
     * @param   token       The address of to be sent ERC20 token.
     * @param   recipient   The receiver of the sent asset.
     * @param   amount      The amount of asset to send.
     */
    function transferERC20(
        address token,
        address recipient,
        uint256 amount
    ) external onlyAuthorized nonReentrant {
        require(amount != 0, "transfer amount is zero");
        IERC20Upgradeable(token).safeTransfer(recipient, amount);
        emit TransferERC20Token(token, recipient, amount);
    }

    /**
     * @notice  A helper method to transfer ERC721 to somewhere.
     *
     * @param   token       The address of to be sent ERC721 token.
     * @param   tokenID     The ID of token.
     * @param   recipient   The receiver of the sent asset.
     */
    function transferERC721(
        address token,
        uint256 tokenID,
        address recipient
    ) external onlyAuthorized nonReentrant {
        IERC721Upgradeable(token).safeTransferFrom(address(this), recipient, tokenID);
        emit TransferERC721Token(token, tokenID, recipient);
    }

    /**
     * @notice  Execute a transaction from vault.
     *          Usually, calling this method is to handle some special asset which cannot be achieved by transferXXX methods.
     *
     * @param   to      The target address which the transaction is to send to.
     * @param   data    A bytes array contains calldata.
     * @param   value   The value of ethers to be sent with the transation.
     */
    function execute(
        address to,
        bytes calldata data,
        uint256 value
    ) external onlyAuthorized nonReentrant {
        AddressUpgradeable.functionCallWithValue(to, data, value);
        emit ExecuteTransaction(to, data, value);
    }

    bytes32[50] private __gap;
}

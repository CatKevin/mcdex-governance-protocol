// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interfaces/IL2ArbNetwork.sol";
import "../interfaces/IDataExchange.sol";
import "../interfaces/IAuthenticator.sol";
import "../Environment.sol";

/**
 * @notice  MintInitiator is used to send mint request submitted from DAO from L2 to L1.
 * @dev     MintInitiator will be deployed on L2.
 */
contract MockMintInitiator is Initializable, Environment {
    using AddressUpgradeable for address;

    IAuthenticator public authenticator;

    address internal _l1Minter;

    event SendMintRequest(uint8 releaseType, address indexed recipient, uint256 amount);

    /**
     * @notice Different to other authorized contract, only admin is able to call.
     */
    modifier onlyAuthorized() {
        require(authenticator.hasRoleOrAdmin(0, msg.sender), "caller is not authorized");
        _;
    }

    /**
     * @notice  Initialzie the mint initiator contract.
     *
     * @param   authenticator_  The address of authentication controller that can determine who is able to call
     *                          admin interfaces.
     */
    function initialize(address authenticator_, address l1Minter) external initializer {
        require(authenticator_ != address(0), "authenticator is the zero address");
        authenticator = IAuthenticator(authenticator_);
        _l1Minter = l1Minter;
    }

    function getL1Minter() public view virtual returns (address) {
        return _l1Minter;
    }

    /**
     * @notice  Send a mint request to L1.
     *
     * @param   releaseType A enum to indicate on which network the mint recipient is located.
     *                      The optional values are None, ToL1 and ToL2 (0, 1, 2).
     * @param   recipient   The address of minted MCB receiver.
     * @param   amount      The amount to be minted of this request.
     */
    function sendMintRequest(
        uint8 releaseType,
        address recipient,
        uint256 amount
    ) external onlyAuthorized {
        _l1Minter.functionCall(
            abi.encodeWithSignature(
                "receiveBaseMintRequestFromL2(uint8,address,uint256)",
                releaseType,
                recipient,
                amount
            )
        );
        emit SendMintRequest(releaseType, recipient, amount);
    }

    bytes32[50] private __gap;
}

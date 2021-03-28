pragma solidity 0.7.4;
// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./interfaces/IAuthenticator.sol";

/**
 * @notice  Vault is a contract to hold various assets from different source.
 */
contract OperatorProxy is Initializable {
    using AddressUpgradeable for address;

    bytes32 public constant OPERATOR_ADMIN_ROLE = keccak256("OPERATOR_ADMIN_ROLE");

    IAuthenticator public authenticator;

    event ExecuteTransaction(address indexed to, bytes data, uint256 value);

    receive() external payable {}

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(OPERATOR_ADMIN_ROLE, msg.sender),
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
        authenticator = IAuthenticator(authenticator_);
    }

    function execute(
        address to,
        bytes calldata data,
        uint256 value
    ) external onlyAuthorized {
        AddressUpgradeable.functionCallWithValue(to, data, value);
        emit ExecuteTransaction(to, data, value);
    }
}

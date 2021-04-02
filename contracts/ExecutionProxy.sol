// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IAuthenticator.sol";

/**
 * @notice  ExecutionProxy is a proxy that can forward transaction with authentication.
 */
contract ExecutionProxy is Initializable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address;

    bytes32 public OPERATOR_ADMIN_ROLE;

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
    function initialize(address authenticator_, bytes32 adminRole) external initializer {
        require(authenticator_ != address(0), "authenticator is the zero address");
        authenticator = IAuthenticator(authenticator_);
        OPERATOR_ADMIN_ROLE = adminRole;
    }

    /**
     * @notice  Execute a customized transaction.
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

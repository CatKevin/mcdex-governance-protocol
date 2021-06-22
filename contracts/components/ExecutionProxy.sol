// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IAuthenticator.sol";

/**
 * @notice  ExecutionProxy is a proxy that can forward transaction with authentication.
 */
contract ExecutionProxy is Initializable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address;

    bytes32 public OPERATOR_ADMIN_ROLE;

    IAuthenticator public authenticator;
    mapping(bytes4 => bool) public blockedMethods;

    event ExecuteTransaction(address indexed to, bytes data, uint256 value);
    event AddBlockedMethod(string method);
    event RemoveBlockedMethod(string method);

    receive() external payable {}

    modifier onlyAdmin() {
        require(authenticator.hasRoleOrAdmin(0, msg.sender), "caller is not authorized");
        _;
    }

    function isMethodBlocked(string calldata method) external view returns (bool) {
        bytes4 selector = bytes4(keccak256(bytes(method)));
        return blockedMethods[selector];
    }

    function addBlockedMethod(string calldata method) external onlyAdmin {
        bytes4 selector = bytes4(keccak256(bytes(method)));
        require(!blockedMethods[selector], "method is already blocked");
        blockedMethods[selector] = true;
        emit AddBlockedMethod(method);
    }

    function removeBlockedMethod(string calldata method) external onlyAdmin {
        bytes4 selector = bytes4(keccak256(bytes(method)));
        require(blockedMethods[selector], "method is not blocked");
        blockedMethods[selector] = false;
        emit RemoveBlockedMethod(method);
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
    ) external nonReentrant {
        _ensureCallerNotBlocked(data);
        AddressUpgradeable.functionCallWithValue(to, data, value);
        emit ExecuteTransaction(to, data, value);
    }

    function _ensureCallerNotBlocked(bytes memory data) internal view {
        bytes4 selector;
        assembly {
            selector := mload(add(data, 32))
        }
        if (blockedMethods[selector]) {
            require(authenticator.hasRoleOrAdmin(0, msg.sender), "method is blocked by admin");
        } else {
            require(
                authenticator.hasRoleOrAdmin(OPERATOR_ADMIN_ROLE, msg.sender),
                "caller is unauthorized"
            );
        }
    }

    bytes32[49] private __gap;
}

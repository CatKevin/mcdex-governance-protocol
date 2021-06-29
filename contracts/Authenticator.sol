// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";

contract Authenticator is Initializable, AccessControlUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /**
     * @notice  Initialize set the sender as ADMIN
     *          and the sender should give ADMIN role to timelock after initialization finished.
     */
    function initialize() external initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice  This should be called from external contract, to test if a account has specified role.

     * @param   role    A bytes32 value generated from keccak256("ROLE_NAME").
     * @param   account The account to be checked.
     * @return  True if the account has already granted permissions for the given role.
     */
    function hasRoleOrAdmin(bytes32 role, address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account) || hasRole(role, account);
    }

    bytes32[50] private __gap;
}

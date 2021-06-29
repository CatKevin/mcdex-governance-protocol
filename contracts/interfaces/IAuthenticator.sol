// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IAuthenticator {
    /**
     * @notice  Check if an account has the given role.
     * @param   role    A bytes32 value generated from keccak256("ROLE_NAME").
     * @param   account The account to be checked.
     * @return  True if the account has already granted permissions for the given role.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @notice  This should be called from external contract, to test if a account has specified role.

     * @param   role    A bytes32 value generated from keccak256("ROLE_NAME").
     * @param   account The account to be checked.
     * @return  True if the account has already granted permissions for the given role.
     */
    function hasRoleOrAdmin(bytes32 role, address account) external view returns (bool);
}

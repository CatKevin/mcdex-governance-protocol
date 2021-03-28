// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

interface IAuthenticator {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function hasRoleOrAdmin(bytes32 role, address account) external view returns (bool);
}

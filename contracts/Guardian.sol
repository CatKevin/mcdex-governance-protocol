// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract Guardianship is ContextUpgradeable, OwnableUpgradeable {
    address private _guardian;

    event GuardianshipTransferred(address indexed previousGuardian, address indexed newGuardian);

    constructor() {}

    function guardian() public view virtual returns (address) {
        return _guardian;
    }

    modifier onlyGuardian() {
        require(_msgSender() == _guardian, "caller is not the guardian");
        _;
    }

    modifier onlyOwnerOrGuardian() {
        require(
            _msgSender() == _guardian || _msgSender() == owner(),
            "caller is not the owner or guardian"
        );
        _;
    }

    function renounceGuardianship() public virtual onlyGuardian {
        emit GuardianshipTransferred(_guardian, address(0));
        _guardian = address(0);
    }

    function transferGuardianship(address newGuardian) public virtual onlyOwnerOrGuardian {
        require(newGuardian != address(0), "new guardian is the zero address");
        emit OwnershipTransferred(_guardian, newGuardian);
        _guardian = newGuardian;
    }
}

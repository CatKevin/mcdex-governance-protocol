// SPDX-License-Identifier: GPL
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/IBeacon.sol";

import { IUSDConvertor } from "../interfaces/IUSDConvertor.sol";

import { UniV3Wrapper } from "./UniV3Wrapper.sol";

contract UniV3WrapperFactory is Ownable, IBeacon {
    using Address for address;

    address public master;

    mapping(bytes32 => address) public wrappers;

    event CreateWrapper(bytes path, bytes32 digest, address instance);
    event UpgradeMasterContract(address oldMaster, address newMaster);

    constructor() Ownable() {
        master = address(new UniV3Wrapper());
    }

    function queryInstance(bytes memory path_) external view returns (address) {
        return wrappers[_digest(path_)];
    }

    function createWrapper(bytes memory path_) external onlyOwner {
        bytes32 digest = _digest(path_);
        bytes memory initializeData = abi.encodeWithSignature("initialize(bytes)", path_);
        address slave = address(new BeaconProxy(address(this), initializeData));
        wrappers[digest] = slave;
        emit CreateWrapper(path_, digest, slave);
    }

    function updatePath(bytes calldata oldPath, bytes calldata newPath) external onlyOwner {
        require(_isPathExist(oldPath), "old path not exists");
        require(!_isPathExist(newPath), "new path is already exists");
        bytes32 oldDigest = _digest(oldPath);
        bytes32 newDigest = _digest(newPath);
        UniV3Wrapper(wrappers[oldDigest]).setPath(newPath);
        wrappers[newDigest] = wrappers[oldDigest];
        wrappers[oldDigest] = address(0);
    }

    function upgradeMasterContract(address master_) external onlyOwner {
        require(master_.isContract(), "new master must be contract");
        emit UpgradeMasterContract(master, master_);
        master = master_;
    }

    function implementation() external view virtual override returns (address) {
        return master;
    }

    function _isPathExist(bytes memory path_) internal view returns (bool) {
        return wrappers[_digest(path_)] == address(0);
    }

    function _digest(bytes memory path_) internal pure returns (bytes32) {
        return keccak256(path_);
    }
}

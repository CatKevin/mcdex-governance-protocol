pragma solidity 0.7.4;
// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

contract Vault is OwnableUpgradeable {
    // using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    receive() external payable {}

    function transferEther(address to, uint256 value) external onlyOwner {
        AddressUpgradeable.sendValue(payable(to), value);
    }

    function callContract(
        address to,
        bytes calldata data,
        uint256 value
    ) external onlyOwner {
        AddressUpgradeable.functionCallWithValue(to, data, value);
    }
}

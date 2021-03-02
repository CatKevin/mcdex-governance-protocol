pragma solidity 0.7.4;
// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract Vault is Initializable, OwnableUpgradeable {
    // using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    receive() external payable {}

    function initialize(address vaultKeeper) external initializer {
        __Ownable_init();
        transferOwnership(vaultKeeper);
    }

    function transferEther(address to, uint256 value) external onlyOwner {
        AddressUpgradeable.sendValue(payable(to), value);
    }

    function transferERC20(
        address tokenAddress,
        address to,
        uint256 value
    ) external onlyOwner {
        IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        IERC20Upgradeable(token).transfer(to, value);
        require(balance.sub(token.balanceOf(address(this))) == value, "balance mismatch");
    }

    function callContract(
        address to,
        bytes calldata data,
        uint256 value
    ) external onlyOwner {
        AddressUpgradeable.functionCallWithValue(to, data, value);
    }
}

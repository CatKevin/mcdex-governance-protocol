// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./interfaces/IComponent.sol";

contract BalanceBroadcaster is Initializable {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet internal _components;

    event AddListener(address indexed component);
    event RemoveListener(address indexed component);

    function __BalanceBroadcaster_init() internal virtual initializer {}

    /**
     * @notice  Return the count of registered components.
     */
    function componentCount() external view returns (uint256) {
        return _components.length();
    }

    /**
     * @notice  Check if a address is a registered component in broadcaster.
     */
    function isComponent(address component) external view returns (bool) {
        return _components.contains(component);
    }

    /**
     * @notice  Get registered components within [begin, end) as an array of addresses.
     */
    function listComponents(uint256 begin, uint256 end)
        public
        view
        returns (address[] memory result)
    {
        require(end > begin, "begin should be lower than end");
        uint256 length = _components.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = (end <= length) ? end : length;
        result = new address[](safeEnd.sub(begin));
        for (uint256 i = begin; i < safeEnd; i++) {
            result[i.sub(begin)] = _components.at(i);
        }
        return result;
    }

    function _addComponent(address component) internal {
        require(!_components.contains(component), "component already exists");
        require(IComponent(component).baseToken() == address(this), "owner of component mismatch");
        _components.add(component);
        emit AddListener(component);
    }

    function _removeComponent(address component) internal {
        require(_components.contains(component), "component not exists");
        _components.remove(component);
        emit RemoveListener(component);
    }

    function _beforeMintingToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) internal {
        uint256 length = _components.length();
        for (uint256 i = 0; i < length; i++) {
            IComponent(_components.at(i)).beforeMintingToken(account, amount, totalSupply);
        }
    }

    function _beforeBurningToken(
        address account,
        uint256 amount,
        uint256 totalSupply
    ) internal {
        uint256 length = _components.length();
        for (uint256 i = 0; i < length; i++) {
            IComponent(_components.at(i)).beforeBurningToken(account, amount, totalSupply);
        }
    }

    bytes32[50] private __gap;
}

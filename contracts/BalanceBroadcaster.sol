// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./libraries/SafeOwnable.sol";
import "./interfaces/IComponent.sol";

contract BalanceBroadcaster is SafeOwnable {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet internal _components;

    event AddComponent(address indexed component);
    event RemoveComponent(address indexed component);

    function __BalanceBroadcaster_init_unchained() internal virtual initializer {}

    function componentCount() public view returns (uint256) {
        return _components.length();
    }

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

    function addComponent(address component) public onlyOwner {
        require(!_components.contains(component), "component already exists");
        require(IComponent(component).baseToken() == address(this), "owner of component mismatch");
        _components.add(component);
        emit AddComponent(component);
    }

    function removeComponent(address component) public onlyOwner {
        require(_components.contains(component), "component not exists");
        _components.remove(component);
        emit RemoveComponent(component);
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

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract ShareBank is Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address internal _shareToken;
    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;

    event Stake(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount);

    function __Bank_init(address shareToken_) internal initializer {
        __Bank_init_unchained(shareToken_);
    }

    function __Bank_init_unchained(address shareToken_) internal initializer {
        _shareToken = shareToken_;
    }

    function shareToken() public view returns (address) {
        return _shareToken;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        require(amount > 0, "cannot stake zero amount");
        IERC20Upgradeable(_shareToken).safeTransferFrom(msg.sender, address(this), amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        emit Stake(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount > 0, "cannot withdraw zero amount");
        require(amount <= _balances[msg.sender], "insufficient balance");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        IERC20Upgradeable(_shareToken).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
}

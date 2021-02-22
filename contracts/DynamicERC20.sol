// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./XMCB.sol";

abstract contract DynamicERC20 is XMCB {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant WONE = 1e18;

    IERC20Upgradeable public rawToken;
    uint256 public withdrawalPenaltyRate;

    event Depoist(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount, uint256 penalty);

    constructor(uint256 withdrawalPenaltyRate_) {
        withdrawalPenaltyRate = withdrawalPenaltyRate_;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _wmul(_totalSupply, _balanceFactor());
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _wmul(_balances[account], _balanceFactor());
    }

    function deposit(uint256 amount) public virtual {
        require(amount > 0, "zero amount");
        _deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) public virtual {
        require(amount != 0, "zero amount");
        require(amount <= balanceOf(msg.sender), "exceeded withdrawable balance");
        _withdraw(msg.sender, amount);
    }

    function _deposit(address account, uint256 amount) internal virtual {
        rawToken.safeTransferFrom(account, address(this), amount);
        _mint(account, amount);
        emit Depoist(account, amount);
    }

    function _withdraw(address account, uint256 amount) internal virtual {
        _burn(account, amount);

        uint256 penalty = (_totalSupply != 0) ? _wmul(amount, withdrawalPenaltyRate) : 0;
        rawToken.safeTransferFrom(address(this), account, amount.sub(penalty));

        emit Withdraw(account, amount, penalty);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        uint256 internalAmount = _wdiv(amount, _balanceFactor());
        super._mint(account, internalAmount);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        uint256 internalAmount = _wdiv(amount, _balanceFactor());
        super._burn(account, internalAmount);
    }

    function _balanceFactor() internal view returns (uint256) {
        if (_totalSupply == 0) {
            return WONE;
        }
        return _wdiv(rawToken.balanceOf(address(this)), totalSupply());
    }

    function _wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y).add(WONE / 2) / WONE;
    }

    function _wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(WONE).add(y / 2).div(y);
    }
}

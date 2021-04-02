// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IAuthenticator.sol";

import "./Comp.sol";
import "./BalanceBroadcaster.sol";

contract XMCB is
    Initializable,
    ReentrancyGuardUpgradeable,
    ContextUpgradeable,
    Comp,
    BalanceBroadcaster
{
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant XMCB_ADMIN_ROLE = keccak256("XMCB_ADMIN_ROLE");
    uint256 private constant WONE = 1e18;

    IAuthenticator public authenticator;
    IERC20Upgradeable public rawToken;
    uint256 public withdrawalPenaltyRate;

    uint96 internal _rawTotalSupply;

    event Depoist(address indexed account, uint256 amount);
    event Withdraw(address indexed account, uint256 amount, uint256 penalty);
    event SetWithdrawalPenaltyRate(uint256 previousPenaltyRate, uint256 newPenaltyRate);

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(XMCB_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    /**
     * @notice  initialize XMCB token.
     * @param   authenticator_          Owner of XMCB who is able to set withdraw penalty rate.
     * @param   rawToken_               The token used as collateral for XMCB.
     * @param   withdrawalPenaltyRate_  The penalty rate when user withdaw.
     *                                  The deducted part will be added to all remining holders.
     */
    function initialize(
        address authenticator_,
        address rawToken_,
        uint256 withdrawalPenaltyRate_
    ) external initializer {
        require(authenticator_ != address(0), "authenticator is the zero address");
        require(rawToken_.isContract(), "raw token must be a contract");
        require(withdrawalPenaltyRate_ <= WONE, "new withdrawalPenaltyRate exceed 100%");

        __Context_init();
        __ReentrancyGuard_init();
        __Comp_init();
        __BalanceBroadcaster_init();

        authenticator = IAuthenticator(authenticator_);
        rawToken = IERC20Upgradeable(rawToken_);
        withdrawalPenaltyRate = withdrawalPenaltyRate_;
    }

    /**
     * @notice  The balance of an account, also known as weighted balance.
     *          The balance is affected by a magnification factor,
     *          which is changed on every withdrawal (expect the last time).
     *          This is how the holders share the profit from withdrawal penalty.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _wmul(_balances[account], _balanceFactor());
    }

    /**
     * @notice  Comparing to `balanceOf`, raw balance indicates the unweighted balance.
     *          This may be useful for other contract which takes XMCB's balance as reference.
     */
    function rawBalanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice  Like `rawBalanceOf`, this is the unweighted total supply.
     */
    function rawTotalSupply() public view virtual returns (uint256) {
        return uint256(_rawTotalSupply);
    }

    /**
     * @notice  Set withdrawal penalty rate. Only available to owner of XMCB.
     * @param   withdrawalPenaltyRate_  A fixed-point decimal, when 1e18 == 100% and 1e16 == 1%.
     */
    function setWithdrawalPenaltyRate(uint256 withdrawalPenaltyRate_)
        external
        virtual
        onlyAuthorized
    {
        require(withdrawalPenaltyRate_ <= WONE, "new withdrawalPenaltyRate exceed 100%");
        emit SetWithdrawalPenaltyRate(withdrawalPenaltyRate, withdrawalPenaltyRate_);
        withdrawalPenaltyRate = withdrawalPenaltyRate_;
    }

    /**
     * @notice  Deposit `rawToken` for XMCB token. The exchange rate is always 1:1.
     * @param   amount  The amount of `rawToken` to deposit.
     */
    function deposit(uint256 amount) external virtual nonReentrant {
        require(amount > 0, "zero amount");
        _beforeMintingToken(_msgSender(), amount, _totalSupply);
        _deposit(_msgSender(), amount);
    }

    /**
     * @notice  Exchange an equal amount of XMCB for `rawToken`. A withrawal penalty will be applied on the amount.
     *          User is expected to get `amount * (1 - withdrawalPenaltyRate)` token back.
     * @param   amount  The amount of `rawToken` to withdraw.
     */
    function withdraw(uint256 amount) external virtual nonReentrant {
        require(amount != 0, "zero amount");
        require(amount <= balanceOf(_msgSender()), "exceeded withdrawable balance");
        _beforeBurningToken(_msgSender(), amount, _totalSupply);
        _withdraw(_msgSender(), amount);
    }

    /**
     * @notice  Add a component to list. A component means a external contract which is able to receive deposit / withdraw
     *          notification from XMCB.
     * @param   component   The address of component to add.
     */
    function addComponent(address component) external virtual onlyAuthorized {
        _addComponent(component);
    }

    /**
     * @notice  Remove a component from list. A component means a external contract which is able to receive deposit / withdraw
     *          notification from XMCB.
     * @param   component   The address of component to add.
     */
    function removeComponent(address component) external virtual onlyAuthorized {
        _removeComponent(component);
    }

    function _deposit(address account, uint256 amount) internal virtual {
        rawToken.safeTransferFrom(account, address(this), amount);
        _mintRaw(account, _wdiv(amount, _balanceFactor()));
        _totalSupply = add96(
            _totalSupply,
            safe96(amount, "XMCB::_deposit: amount exceeds 96 bits"),
            "XMCB::_deposit: deposit amount overflows"
        );
        emit Depoist(account, amount);
    }

    function _withdraw(address account, uint256 amount) internal virtual {
        uint256 penalty = (amount == _totalSupply) ? 0 : _wmul(amount, withdrawalPenaltyRate);
        rawToken.safeTransfer(account, amount.sub(penalty));
        _burnRaw(account, _wdiv(amount, _balanceFactor()));
        _totalSupply = sub96(
            _totalSupply,
            safe96(amount.sub(penalty), "XMCB::_withdraw: amount exceeds 96 bits"),
            "XMCB::_withdraw: withdraw amount underflows"
        );
        emit Withdraw(account, amount, penalty);
    }

    function _mintRaw(address account, uint256 amount) internal virtual {
        uint96 safeAmount = safe96(amount, "XMCB::mint: amount exceeds 96 bits");
        _balances[account] = add96(
            _balances[account],
            safeAmount,
            "XMCB::_increaseBalance: balance overflows"
        );
        _rawTotalSupply = add96(
            _rawTotalSupply,
            safeAmount,
            "XMCB::_deposit: deposit amount overflows"
        );
        _moveDelegates(address(0), getDelegate(account), safeAmount);
    }

    function _burnRaw(address account, uint256 amount) internal virtual {
        uint96 safeAmount = safe96(amount, "XMCB::burn: amount exceeds 96 bits");
        _balances[account] = sub96(
            _balances[account],
            safeAmount,
            "XMCB::_decreaseBalance: balance overflows"
        );
        _rawTotalSupply = sub96(
            _rawTotalSupply,
            safeAmount,
            "XMCB::_deposit: deposit amount overflows"
        );
        _moveDelegates(getDelegate(account), address(0), safeAmount);
    }

    function _balanceFactor() internal view returns (uint256) {
        if (_rawTotalSupply == 0) {
            return WONE;
        }
        return _wdiv(_totalSupply, _rawTotalSupply);
    }

    function _wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(y) / WONE;
    }

    function _wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mul(WONE).add(y / 2).div(y);
    }

    // reserved for upgrade
    bytes32[50] private __gap;
}

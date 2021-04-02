// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../../interfaces/IAuthenticator.sol";
import "hardhat/console.sol";

interface IXMCB is IERC20 {
    function rawTotalSupply() external view returns (uint256);

    function rawBalanceOf(address account) external view returns (uint256);
}

contract RewardDistribution is Context, Ownable {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant REWARD_DISTRIBUTION_ADMIN_ROLE =
        keccak256("REWARD_DISTRIBUTION_ADMIN_ROLE");

    IXMCB public xmcb;
    IAuthenticator public authenticator;

    struct RewardPlan {
        IERC20 rewardToken;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
    }
    mapping(address => RewardPlan) internal _rewardPlans;
    EnumerableSet.AddressSet internal _activeReward;

    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward, uint256 periodFinish);
    event RewardRateChanged(uint256 previousRate, uint256 currentRate, uint256 periodFinish);
    event RewardPlanCreated(address indexed token, uint256 rewardRate);

    modifier onlyAuthorized() {
        require(
            authenticator.hasRoleOrAdmin(REWARD_DISTRIBUTION_ADMIN_ROLE, msg.sender),
            "caller is not authorized"
        );
        _;
    }

    modifier updateReward(address token, address account) {
        _updateReward(token, account);
        _;
    }

    modifier onlyOnExistPlan(address token) {
        require(hasPlan(token), "plan not exists");
        _;
    }

    constructor(address authenticator_, address XMCB_) Ownable() {
        require(authenticator_.isContract(), "authenticator must be a contract");
        require(XMCB_.isContract(), "authenticator must be a contract");

        authenticator = IAuthenticator(authenticator_);
        xmcb = IXMCB(XMCB_);
    }

    /**
     * @notice  The address of base token.
     */
    function baseToken() public view returns (address) {
        return address(xmcb);
    }

    /**
     * @notice  Implement of IComponent interface which is call when user deposits MCB into XMCB.
     */
    function beforeMintingToken(
        address account,
        uint256,
        uint256
    ) external {
        uint256 length = _activeReward.length();
        for (uint256 i = 0; i < length; i++) {
            _updateReward(_activeReward.at(i), account);
        }
    }

    /**
     * @notice  Implement of IComponent interface which is call when user withdraws MCB from XMCB.
     */
    function beforeBurningToken(
        address account,
        uint256,
        uint256
    ) external {
        uint256 length = _activeReward.length();
        for (uint256 i = 0; i < length; i++) {
            _updateReward(_activeReward.at(i), account);
        }
    }

    /**
     * @notice  Check if there is any reward plan for given token.
     */
    function hasPlan(address token) public view returns (bool) {
        return address(_rewardPlans[token].rewardToken) != address(0);
    }

    /**
     * @notice  Create a new reward plan for given token, setting the reward rate. Duplicated creation will be reverted.
     */
    function createRewardPlan(address token, uint256 rewardRate) public onlyAuthorized {
        require(token != address(0), "invalid reward token");
        require(token.isContract(), "reward token must be contract");
        require(!hasPlan(token), "plan already exists");
        _rewardPlans[token].rewardToken = IERC20(token);
        _rewardPlans[token].rewardRate = rewardRate;
        _activeReward.add(token);
        emit RewardPlanCreated(token, rewardRate);
    }

    /**
     * @notice  Get the reward tokens, including the finished reward plan.
     */
    function getRewardTokens() public view returns (address[] memory) {
        uint256 tokenCount = _activeReward.length();
        address[] memory results = new address[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            results[i] = _activeReward.at(i);
        }
        return results;
    }

    /**
     * @notice  Get the finished time and reward rate of a reward plan.
     */
    function getRewardPlan(address token) public view returns (uint256, uint256) {
        RewardPlan storage plan = _rewardPlans[token];
        return (plan.periodFinish, plan.rewardRate);
    }

    /**
     * @notice  Set reward distribution rate. If there is unfinished distribution, the end time will be changed
     *          according to change of newRewardRate.
     *
     * @param   newRewardRate   New reward distribution rate.
     */
    function setRewardRate(address token, uint256 newRewardRate)
        public
        virtual
        onlyAuthorized
        onlyOnExistPlan(token)
        updateReward(token, address(0))
    {
        RewardPlan storage plan = _rewardPlans[token];
        if (newRewardRate == 0) {
            plan.periodFinish = _getBlockNumber();
        } else if (plan.periodFinish != 0) {
            plan.periodFinish = plan
                .periodFinish
                .sub(plan.lastUpdateTime)
                .mul(plan.rewardRate)
                .div(newRewardRate)
                .add(_getBlockNumber());
        }
        emit RewardRateChanged(plan.rewardRate, newRewardRate, plan.periodFinish);
        plan.rewardRate = newRewardRate;
    }

    /**
     * @notice  Add new distributable reward to current pool, this will extend an exist distribution or
     *          start a new distribution if previous one is already ended.
     *
     * @param   reward  Amount of reward to add.
     */
    function notifyRewardAmount(address token, uint256 reward)
        public
        virtual
        onlyAuthorized
        onlyOnExistPlan(token)
        updateReward(token, address(0))
    {
        require(reward > 0, "reward is zero");
        RewardPlan storage plan = _rewardPlans[token];
        require(plan.rewardRate > 0, "rewardRate is zero");
        uint256 period = reward.div(plan.rewardRate);
        // already finished or not initialized
        if (_getBlockNumber() > plan.periodFinish) {
            plan.lastUpdateTime = _getBlockNumber();
            plan.periodFinish = _getBlockNumber().add(period);
        } else {
            // not finished or not initialized
            plan.periodFinish = plan.periodFinish.add(period);
        }
        emit RewardAdded(reward, plan.periodFinish);
    }

    /**
     * @notice  Return end time if last distribution is done or current timestamp.
     */
    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        RewardPlan storage plan = _rewardPlans[token];
        return _getBlockNumber() <= plan.periodFinish ? _getBlockNumber() : plan.periodFinish;
    }

    /**
     * @notice  Return the per token amount of reward.
     *          The expected reward of user is: [amount of share] x rewardPerToken - claimedReward.
     */
    function rewardPerToken(address token) public view returns (uint256) {
        RewardPlan storage plan = _rewardPlans[token];
        uint256 totalSupply = xmcb.rawTotalSupply();
        if (totalSupply == 0) {
            return plan.rewardPerTokenStored;
        }
        return
            plan.rewardPerTokenStored.add(
                lastTimeRewardApplicable(token)
                    .sub(plan.lastUpdateTime)
                    .mul(plan.rewardRate)
                    .mul(1e18)
                    .div(totalSupply)
            );
    }

    /**
     * @notice  Return real time reward of account.
     */
    function earned(address token, address account) public view returns (uint256) {
        RewardPlan storage plan = _rewardPlans[token];
        uint256 balance = xmcb.rawBalanceOf(account);
        return
            balance
                .mul(rewardPerToken(token).sub(plan.userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(plan.rewards[account]);
    }

    /**
     * @notice  Claim remaining reward of a token for caller.
     */
    function getReward(address token) public updateReward(token, _msgSender()) {
        RewardPlan storage plan = _rewardPlans[token];
        address account = _msgSender();
        uint256 reward = earned(token, account);
        if (reward > 0) {
            plan.rewards[account] = 0;
            plan.rewardToken.safeTransfer(account, reward);
            emit RewardPaid(account, reward);
        }
    }

    /**
     * @notice  Claim remaining reward of all tokens for caller.
     */
    function getAllRewards() public {
        uint256 length = _activeReward.length();
        for (uint256 i = 0; i < length; i++) {
            getReward(_activeReward.at(i));
        }
    }

    function _updateReward(address token, address account) internal {
        RewardPlan storage plan = _rewardPlans[token];
        plan.rewardPerTokenStored = rewardPerToken(token);
        plan.lastUpdateTime = lastTimeRewardApplicable(token);
        if (account != address(0)) {
            plan.rewards[account] = earned(token, account);
            plan.userRewardPerTokenPaid[account] = plan.rewardPerTokenStored;
        }
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./RewardDistribution.sol";

contract Dividends is RewardDistribution {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant DISTRIBUTION_COOL_DOWN = 86400 * 2;

    uint256 public periodStart;

    function __Dividends_init(address rewardToken_) internal initializer {
        __Ownable_init_unchained();
        __RewardDistribution_init_unchained(rewardToken_);
        __Dividends_init_unchained();
    }

    function __Dividends_init_unchained() internal initializer {}

    function notifyRewardAmount(
        uint256 beginBlock,
        uint256 endBlock,
        uint256 reward
    ) external virtual onlyRewardDistribution updateReward(address(0)) {
        require(beginBlock < endBlock, "invalid block range");
        require(
            beginBlock > periodFinish.add(DISTRIBUTION_COOL_DOWN),
            "distribution is cooling down"
        );
        require(rewardRate > 0, "rewardRate is zero");

        periodStart = beginBlock;
        periodFinish = endBlock;
        uint256 period = periodFinish.sub(periodStart);
        rewardRate = reward.div(period);
        emit RewardAdded(reward, periodFinish);
    }

    function addReward(uint256 reward)
        external
        virtual
        onlyRewardDistribution
        updateReward(address(0))
    {
        require(reward > 0, "reward is zero");
        uint256 currentBlockNumber = block.number;
        require(
            currentBlockNumber >= periodStart && currentBlockNumber < periodFinish,
            "no living distribution"
        );
        uint256 blockLeft = periodFinish.sub(currentBlockNumber);
        uint256 newRewardRate =
            periodFinish.sub(lastUpdateTime).mul(rewardRate).add(reward).div(blockLeft);
        rewardRate = newRewardRate;
        emit RewardAdded(reward, periodFinish);
        emit RewardRateChanged(rewardRate, newRewardRate, periodFinish);
    }
}

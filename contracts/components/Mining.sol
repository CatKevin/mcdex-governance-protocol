// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "./RewardDistribution.sol";

contract Mining is RewardDistribution {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function __Mining_init(address rewardToken_) internal initializer {
        __Ownable_init_unchained();
        __RewardDistribution_init_unchained(rewardToken_);
        __Mining_init_unchained();
    }

    function __Mining_init_unchained() internal initializer {}

    function setRewardRate(uint256 newRewardRate)
        external
        virtual
        onlyRewardDistribution
        updateReward(address(0))
    {
        if (newRewardRate == 0) {
            periodFinish = block.number;
        } else if (periodFinish != 0) {
            periodFinish = periodFinish.sub(lastUpdateTime).mul(rewardRate).div(newRewardRate).add(
                block.number
            );
        }
        emit RewardRateChanged(rewardRate, newRewardRate);
        rewardRate = newRewardRate;
    }

    function notifyRewardAmount(uint256 reward)
        external
        virtual
        onlyRewardDistribution
        updateReward(address(0))
    {
        require(rewardRate > 0, "rewardRate is zero");
        uint256 period = reward.div(rewardRate);
        // already finished or not initialized
        if (block.number > periodFinish) {
            lastUpdateTime = block.number;
            periodFinish = block.number.add(period);
            emit RewardAdded(reward);
        } else {
            // not finished or not initialized
            periodFinish = periodFinish.add(period);
            emit RewardAdded(reward);
        }
    }
}

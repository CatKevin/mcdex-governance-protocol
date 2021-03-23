const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from './utils';

async function main(accounts: any[]) {
    const user0 = accounts[0]

    const usdc = await createContract("CustomERC20", ["USDC", "USDC", 6]);

    const RewardDistribution = await createFactory("TestRewardDistribution");
    const rewardDistrubution = await RewardDistribution.attach("0x1F7e017b0b23F6CADa4dCf9FbC422B520164A7C7")

    await rewardDistrubution.createRewardPlan(usdc.address, "2000000");
    await rewardDistrubution.notifyRewardAmount(usdc.address, "200000000000");

    console.table([
        ["usdc", usdc.address],
    ])
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
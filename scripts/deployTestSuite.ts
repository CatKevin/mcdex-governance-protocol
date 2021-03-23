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
    // mcb
    const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    // mcb
    const xmcb = await createContract("XMCB");
    await xmcb.initialize(user0.address, mcb.address, toWei("0.05"))
    // timelock & governor
    const timelock = await createContract("TestTimelock", [user0.address, 86400]);
    const governor = await createContract("TestGovernorAlpha", [timelock.address, xmcb.address, user0.address]);

    var starttime = (await ethers.provider.getBlock()).timestamp;
    await timelock.skipTime(0);

    const eta = starttime + 86400 + 1;
    await timelock.queueTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    )
    await timelock.skipTime(86400 + 1);
    await timelock.executeTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    )
    await governor.__acceptAdmin();

    const vault = await createContract("Vault");
    await vault.initialize(timelock.address);
    const valueCapture = await createContract("ValueCapture");
    await valueCapture.initialize(vault.address, user0.address);

    // test in & out
    const tokenIn1 = await createContract("CustomERC20", ["TKN1", "TKN1", 18]);
    const tokenOu1 = await createContract("CustomERC20", ["USD1", "USD1", 18]);

    // converter
    const seller1 = await createContract("ConstantSeller", [tokenIn1.address, tokenOu1.address, toWei("4")])

    await valueCapture.setUSDToken(tokenOu1.address, 18);
    await valueCapture.setUSDConverter(tokenIn1.address, seller1.address);

    await timelock.setTimestamp(0)
    await governor.setTimestamp(0)

    // mining
    const rewardDistrubution = await createContract("TestRewardDistribution", [user0.address, xmcb.address]);
    await xmcb.addComponent(rewardDistrubution.address);

    await rewardDistrubution.createRewardPlan(mcb.address, toWei("0.2"));
    await rewardDistrubution.notifyRewardAmount(mcb.address, toWei("20000"));

    const minter = await createContract("Minter", [
        mcb.address,
        valueCapture.address,
        user0.address,
        toWei("0.25"),
        toWei("10000000"),
        Math.floor(Date.now() / 1000),
        toWei("86400") // 1 persecond
    ]);

    console.table([
        ["mcb", mcb.address],
        ["xmcb", xmcb.address],
        ["timelock", timelock.address],
        ["governor", governor.address],
        ["vault", vault.address],
        ["valueCapture", valueCapture.address],
        ["tokenIn1", tokenIn1.address],
        ["tokenOu1", tokenOu1.address],
        ["seller1", seller1.address],
        ["mining", rewardDistrubution.address],
        ["minter", minter.address],
    ])

}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
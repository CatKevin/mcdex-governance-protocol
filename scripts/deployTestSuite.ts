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
    // auth
    const auth = await createContract("Authenticator");
    await auth.initialize();
    // mcb
    const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    // mcb
    const xmcb = await createContract("XMCB");
    await xmcb.initialize(auth.address, mcb.address, toWei("0.05"))

    // timelock & governor
    const timelock = await createContract("TestTimelock", [user0.address, 86400]);
    const governor = await createContract("TestGovernorAlpha", [mcb.address, timelock.address, xmcb.address, user0.address]);

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
    await vault.initialize(auth.address);

    const valueCapture = await createContract("ValueCapture");
    await valueCapture.initialize(auth.address, vault.address);

    await auth.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", timelock.address);

    // test in & out
    const tokenIn1 = await createContract("CustomERC20", ["TKN1", "TKN1", 18]);
    const tokenOu1 = await createContract("CustomERC20", ["USD1", "USD1", 18]);

    // converter
    const seller1 = await createContract("ConstantSeller", [tokenIn1.address, tokenOu1.address, toWei("4")])
    const oracle = await createContract("MockTWAPOracle");
    await oracle.setPrice(toWei("5"));

    await valueCapture.addUSDToken(tokenOu1.address, 18);
    await valueCapture.setConvertor(tokenIn1.address, oracle.address, seller1.address, toWei("0.01"));

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
        {
            recipient: vault.address,
            releaseRate: toWei("0.2"),
            mintableAmount: 0,
            mintedAmount: 0,
            maxSupply: toWei("50000000"),
            lastCapturedBlock: 0
        },
        {
            recipient: vault.address,
            releaseRate: toWei("0.55392"),
            mintableAmount: 0,
            mintedAmount: 0,
            maxSupply: toWei("50000000"),
            lastCapturedBlock: 0
        },
    ]);

    console.table([
        ["auth", auth.address],
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
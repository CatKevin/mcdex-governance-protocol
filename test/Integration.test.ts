import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('Integration', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let seriesA;
    let dev;

    let auth;
    let mcb;
    let xmcb;
    let timelock;
    let governor;

    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }

    const fromState = (state) => {
        return ProposalState[state]
    }

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        seriesA = accounts[4];
        dev = accounts[5];

        auth = await createContract("Authenticator");
        await auth.initialize();
        // mcb
        mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        // mcb
        xmcb = await createContract("XMCB");
        await xmcb.initialize(auth.address, mcb.address, toWei("0.05"))

        // timelock & governor
        timelock = await createContract("TestTimelock", [user0.address, 86400]);
        governor = await createContract("TestGovernorAlpha", [mcb.address, timelock.address, xmcb.address, user0.address]);

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
        // const tokenIn1 = await createContract("CustomERC20", ["TKN1", "TKN1", 18]);
        // const tokenOu1 = await createContract("CustomERC20", ["USD1", "USD1", 18]);

        // converter
        // const seller1 = await createContract("ConstantSeller", [tokenIn1.address, tokenOu1.address, toWei("4")])
        // const oracle = await createContract("MockTWAPOracle");
        // await oracle.setPrice(toWei("5"));

        // await valueCapture.addUSDToken(tokenOu1.address, 18);
        // await valueCapture.setConvertor(tokenIn1.address, oracle.address, seller1.address, toWei("0.01"));

        await timelock.setTimestamp(0)
        await governor.setTimestamp(0)

        // mining
        // const rewardDistrubution = await createContract("TestRewardDistribution", [user0.address, xmcb.address]);
        // await xmcb.addComponent(rewardDistrubution.address);

        // await rewardDistrubution.createRewardPlan(mcb.address, toWei("0.2"));
        // await rewardDistrubution.notifyRewardAmount(mcb.address, toWei("20000"));

        const minter = await createContract("Minter", [
            mcb.address,
            valueCapture.address,
            seriesA.address,
            dev.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.5"),
        ]);
    })

    it("full case - mining", async () => {
        // assume there are some mcb holder
        await mcb.mint(user1.address, toWei("100"))
        await mcb.mint(user2.address, toWei("150"))
        await mcb.mint(user3.address, toWei("100"))

        // two of them staking there token for xmcb
        await mcb.connect(user1).approve(xmcb.address, toWei("10000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("10000"));
        await xmcb.connect(user1).deposit(toWei("75"));
        await xmcb.connect(user2).deposit(toWei("25"));

        // their balances should be ...
        expect(await xmcb.balanceOf(user1.address)).to.equal(toWei("75"))
        expect(await xmcb.balanceOf(user2.address)).to.equal(toWei("25"))

        // they want to create a module to mining usd
        const rewardDistrubution = await createContract("TestRewardDistribution", [auth.address, xmcb.address]);
        // ** for test, I'll fix the block number here
        await rewardDistrubution.setBlockNumber(1)
        const xusd = await createContract("CustomERC20", ["xUSD", "xUSD", 6]);
        // await rewardDistrubution.createRewardPlan(xusd.address, "200000"); // 0.2e6
        // await rewardDistrubution.notifyRewardAmount(xusd.address, "1000000000"); // 1000e6

        await governor.connect(user1).propose(
            [xmcb.address, rewardDistrubution.address, rewardDistrubution.address],
            [0, 0, 0],
            [
                "addComponent(address)",
                "createRewardPlan(address,uint256)",
                "notifyRewardAmount(address,uint256)"],
            [
                ethers.utils.defaultAbiCoder.encode(["address"], [rewardDistrubution.address]),
                ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [xusd.address, "200000"]),
                ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [xusd.address, "1000000000"])
            ],
            "add rewardDistrubution"
        )
        await governor.skipBlock(1);
        await governor.connect(user1).castVote(1, true)
        await governor.connect(user2).castVote(1, false)
        var result = await governor.getReceipt(1, user1.address)
        expect(result.hasVoted).to.be.true
        expect(result.support).to.be.true
        expect(result.votes).to.equal(toWei("75"))
        var result = await governor.getReceipt(1, user2.address)
        expect(result.hasVoted).to.be.true
        expect(result.support).to.be.false
        expect(result.votes).to.equal(toWei("25"))

        // some magic ...
        await governor.skipBlock(17280);
        await governor.queue(1);
        await timelock.skipTime(86400);
        await governor.execute(1);

        // now it is there, the mining should start
        expect(await xmcb.isComponent(rewardDistrubution.address)).to.be.true

        // after 10 blocks
        await rewardDistrubution.skipBlock(10);
        expect(await rewardDistrubution.earned(xusd.address, user1.address)).to.equal("1500000")
        expect(await rewardDistrubution.earned(xusd.address, user2.address)).to.equal("500000")
    });
})
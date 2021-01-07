import { expect } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('Minging', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let miner;
    let ctk;
    let rtk;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    beforeEach(async () => {
        ctk = await createContract("CustomERC20", ["CTK", "CTK", 18]);
        rtk = await createContract("CustomERC20", ["RTK", "RTK", 18]);
        miner = await createContract("Mineable");
        await miner.initialize(ctk.address, rtk.address);
    });

    it("stake / withdraw", async () => {
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.mint(user2.address, toWei("10000"));

        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        await ctk.connect(user2).approve(miner.address, toWei("10000"));

        expect(await miner.deposits(user1.address)).to.equal(toWei("0"));
        await miner.connect(user1).stake(toWei("115"));
        expect(await miner.deposits(user1.address)).to.equal(toWei("115"));
        await miner.connect(user1).stake(toWei("221"));
        expect(await miner.deposits(user1.address)).to.equal(toWei("336"));

        expect(await miner.deposits(user2.address)).to.equal(toWei("0"));
        await miner.connect(user2).stake(toWei("20"));
        expect(await miner.deposits(user2.address)).to.equal(toWei("20"));
        await miner.connect(user2).stake(toWei("21"));
        expect(await miner.deposits(user2.address)).to.equal(toWei("41"));

        await expect(miner.connect(user1).stake(toWei("0"))).to.be.revertedWith("cannot stake zero amount");

        await miner.connect(user1).withdraw(toWei("110"));
        expect(await miner.deposits(user1.address)).to.equal(toWei("226"));

        await expect(miner.connect(user1).withdraw(toWei("0"))).to.be.revertedWith("cannot withdraw zero amount");
        await expect(miner.connect(user1).withdraw(toWei("227"))).to.be.revertedWith("insufficient balance");
    })

    it("notifyRewardAmount", async () => {
        await miner.setRewardDistribution(user1.address);

        await expect(miner.setRewardRate(2)).to.be.revertedWith("Caller is not reward distribution");
        await expect(miner.notifyRewardAmount(toWei("100"))).to.be.revertedWith("Caller is not reward distribution");
        await expect(miner.connect(user1).notifyRewardAmount(toWei("100"))).to.be.revertedWith("rewardRate is zero");

        await miner.connect(user1).setRewardRate(toWei("2"));
        let tx = await miner.connect(user1).notifyRewardAmount(toWei("10"));
        let receipt = await tx.wait();
        let blockNumber = receipt.blockNumber;
        expect(await miner.lastUpdateTime()).to.equal(blockNumber);
        expect(await miner.periodFinish()).to.equal(blockNumber + 5);

        await miner.connect(user1).notifyRewardAmount(toWei("20"));
        expect(await miner.lastUpdateTime()).to.equal(blockNumber + 1);
        expect(await miner.periodFinish()).to.equal(blockNumber + 5 + 10);

        let blockNumber2;
        // 150 block / end passed 
        for (let i = 0; i < 20; i++) {
            let tx = await ctk.connect(user1).approve(miner.address, toWei("10000"));
            let receipt = await tx.wait();
            blockNumber2 = receipt.blockNumber;
        }

        expect(blockNumber2).to.be.greaterThan(blockNumber + 5 + 10)

        let tx3 = await miner.connect(user1).notifyRewardAmount(toWei("30"));
        let receipt3 = await tx3.wait();
        let blockNumber3 = receipt3.blockNumber;
        expect(await miner.lastUpdateTime()).to.equal(blockNumber3);
        expect(await miner.periodFinish()).to.equal(blockNumber3 + 15);
    })

    it("setRewardRate", async () => {
        await miner.setRewardDistribution(user1.address);

        await miner.connect(user1).setRewardRate(toWei("2"));
        let tx = await miner.connect(user1).notifyRewardAmount(toWei("100"));
        let receipt = await tx.wait();
        let blockNumber = receipt.blockNumber;
        expect(await miner.lastUpdateTime()).to.equal(blockNumber);
        expect(await miner.periodFinish()).to.equal(blockNumber + 50);
        // (105 - 55) * 2 / 5 + now
        await miner.connect(user1).setRewardRate(toWei("5"));
        expect(await miner.lastUpdateTime()).to.equal(blockNumber + 1);
        expect(await miner.periodFinish()).to.equal(blockNumber + 20);

        let tx2 = await miner.connect(user1).setRewardRate(toWei("0"));
        let receipt2 = await tx2.wait();
        let blockNumber2 = receipt2.blockNumber;
        expect(await miner.lastUpdateTime()).to.equal(blockNumber2);
        expect(await miner.periodFinish()).to.equal(blockNumber2);
    })


    it("earned", async () => {
        await miner.setRewardDistribution(user1.address);

        await ctk.mint(user1.address, toWei("10000"));
        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        await miner.connect(user1).stake(toWei("100"));

        await miner.connect(user1).setRewardRate(toWei("2"));
        await miner.connect(user1).notifyRewardAmount(toWei("20"));
        expect(await miner.earned(user1.address)).to.equal(toWei("0"))

        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        expect(await miner.earned(user1.address)).to.equal(toWei("2"))

        // 10 round max
        for (let i = 0; i < 20; i++) {
            await ctk.connect(user1).approve(miner.address, toWei("10000"));
        }
        expect(await miner.earned(user1.address)).to.equal(toWei("20"))
    })

    it("rewardPerToken", async () => {
        await miner.setRewardDistribution(user1.address);
        await miner.connect(user1).setRewardRate(toWei("2"));
        await miner.connect(user1).notifyRewardAmount(toWei("40"));

        expect(await miner.rewardPerToken()).to.equal(toWei("0"));

        await rtk.mint(miner.address, toWei("10000"));
        await ctk.mint(user1.address, toWei("10000"));
        await ctk.connect(user1).approve(miner.address, toWei("10000"));

        await miner.connect(user1).stake(toWei("100"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0"));

        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0.02"));

        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0.04"));

        await miner.connect(user1).withdraw(toWei("100"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0.06"));

        expect(await rtk.balanceOf(user1.address)).to.equal(toWei("0"));
        expect(await miner.rewards(user1.address)).to.equal(toWei("6"))
        await miner.connect(user1).getReward();
        expect(await rtk.balanceOf(user1.address)).to.equal(toWei("6"));

        await miner.connect(user1).getReward();
        expect(await rtk.balanceOf(user1.address)).to.equal(toWei("6"));
        expect(await miner.userRewardPerTokenPaid(user1.address)).to.equal(toWei("0.06"));

        await ctk.connect(user1).approve(miner.address, toWei("10000"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0.06"));

        await miner.connect(user1).stake(toWei("200"));
        expect(await miner.rewardPerToken()).to.equal(toWei("0.06"));

        await ctk.connect(user1).approve(miner.address, toWei("10000")); // +2
        expect(await miner.rewardPerToken()).to.equal(toWei("0.07"));

        // 0.07 * 200
        expect(await miner.earned(user1.address)).to.equal(toWei("2"))
        await miner.connect(user1).getReward(); // +2
        expect(await rtk.balanceOf(user1.address)).to.equal(toWei("10"));

        expect(await miner.earned(user1.address)).to.equal(toWei("0"))
        await ctk.connect(user1).approve(miner.address, toWei("10000")); // +2
        await ctk.connect(user1).approve(miner.address, toWei("10000")); // +2

        await miner.connect(user1).exit(); // +2
        expect(await rtk.balanceOf(user1.address)).to.equal(toWei("16"));
        expect(await miner.earned(user1.address)).to.equal(toWei("0"))
        expect(await miner.deposits(user1.address)).to.equal(toWei("0"))
    })
})
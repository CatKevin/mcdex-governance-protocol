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

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        console.log("user0", user0.address)
        console.log("user1", user1.address)
        console.log("user2", user2.address)
        console.log("user3", user3.address)
    })

    it("mining list", async () => {

        const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd2 = await createContract("CustomERC20", ["USD", "USD", 6]);

        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(user0.address, mcb.address, toWei("0.05"));

        const rewardDistrubution1 = await createContract("TestRewardDistribution", [user0.address, xmcb.address]);
        const rewardDistrubution2 = await createContract("TestRewardDistribution", [user0.address, xmcb.address]);

        await xmcb.addComponent(rewardDistrubution1.address);
        await xmcb.addComponent(rewardDistrubution2.address);

        expect(await xmcb.componentCount()).to.equal(2)
        var list = await xmcb.listComponents(0, 10);
        expect(list.length).to.equal(2)
        expect(list[0]).to.equal(rewardDistrubution1.address)
        expect(list[1]).to.equal(rewardDistrubution2.address)

        var list = await xmcb.listComponents(1, 2);
        expect(list.length).to.equal(1)
        expect(list[0]).to.equal(rewardDistrubution2.address)

        var list = await xmcb.listComponents(2, 3);
        expect(list.length).to.equal(0)

        await xmcb.removeComponent(rewardDistrubution1.address);
        expect(await xmcb.componentCount()).to.equal(1)
        var list = await xmcb.listComponents(0, 10);
        expect(list.length).to.equal(1)
        expect(list[0]).to.equal(rewardDistrubution2.address)

        await expect(xmcb.removeComponent(rewardDistrubution1.address)).to.be.revertedWith("component not exists")
        await expect(xmcb.addComponent(rewardDistrubution2.address)).to.be.revertedWith("component already exists")
        await expect(xmcb.addComponent(mcb.address)).to.be.revertedWith("reverted")
    })


    it("mining", async () => {

        const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd2 = await createContract("CustomERC20", ["USD", "USD", 6]);

        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(user0.address, mcb.address, toWei("0.05"));

        const rewardDistrubution = await createContract("TestRewardDistribution", [user0.address, xmcb.address]);
        await xmcb.addComponent(rewardDistrubution.address);

        await mcb.mint(user1.address, toWei("10000"));
        await mcb.mint(user2.address, toWei("10000"));
        await mcb.connect(user1).approve(xmcb.address, toWei("10000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("10000"));

        await xmcb.connect(user1).deposit(toWei("100"));
        await xmcb.connect(user2).deposit(toWei("100"));

        await rewardDistrubution.setBlockNumber(1000);

        await rewardDistrubution.createRewardPlan(usd1.address, toWei("2"));
        await rewardDistrubution.createRewardPlan(usd2.address, "3000000");

        // usd1 start
        await rewardDistrubution.notifyRewardAmount(usd1.address, toWei("20000"));
        await rewardDistrubution.skipBlock(1);
        expect(await rewardDistrubution.earned(usd1.address, user1.address)).to.equal(toWei("1"));
        expect(await rewardDistrubution.earned(usd1.address, user2.address)).to.equal(toWei("1"));

        await rewardDistrubution.skipBlock(2);
        expect(await rewardDistrubution.earned(usd1.address, user1.address)).to.equal(toWei("3"));
        expect(await rewardDistrubution.earned(usd1.address, user2.address)).to.equal(toWei("3"));

        await xmcb.connect(user2).withdraw(toWei("100"));
        await rewardDistrubution.skipBlock(1);
        expect(await rewardDistrubution.earned(usd1.address, user1.address)).to.equal(toWei("5"));
        expect(await rewardDistrubution.earned(usd1.address, user2.address)).to.equal(toWei("3"));

        await xmcb.connect(user2).deposit(toWei("105"));
        await rewardDistrubution.skipBlock(1);
        expect(await rewardDistrubution.earned(usd1.address, user1.address)).to.equal(toWei("6"));
        expect(await rewardDistrubution.earned(usd1.address, user2.address)).to.equal(toWei("4"));

    })
})
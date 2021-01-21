import { expect } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('LPGovernor', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;

    let stk;
    let rtk;
    let governor;
    let timelock;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[0];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    beforeEach(async () => {
        stk = await createContract("ShareToken");
        rtk = await createContract("CustomERC20", ["RTK", "RTK", 18]);
        timelock = await createContract("Timelock", [user0.address, 86400]);
        governor = await createContract("LPGovernor");

        // console.table([
        //     ["STK", stk.address],
        //     ["RTK", rtk.address],
        //     ["Timelock", timelock.address],
        //     ["LPGovernor", governor.address],
        // ])

        await stk.initialize("STK", "STK", user0.address);
        await governor.initialize(stk.address, rtk.address, timelock.address, user0.address);
    });

    it("stake / withdraw", async () => {
        await governor.setRewardDistribution(user0.address);

        await stk.mint(user1.address, toWei("1000"));
        await stk.connect(user1).approve(governor.address, toWei("10000"));

        await governor.connect(user1).stake(toWei("666"));
        console.log(fromWei(await stk.balanceOf(user1.address)));

        await governor.connect(user1).withdraw(toWei("666"));
        console.log(fromWei(await stk.balanceOf(user1.address)));

        await governor.connect(user1).stake(toWei("666"));
        console.log(fromWei(await stk.balanceOf(user1.address)));

        await rtk.mint(user0.address, toWei("1000000"));
        await rtk.approve(governor.address, toWei("500"))
        await rtk.transfer(governor.address, toWei("500"));

        await governor.setRewardRate(toWei("2"));
        await governor.notifyRewardAmount(toWei("500"));


        await rtk.approve(governor.address, toWei("500"))
        await rtk.approve(governor.address, toWei("500"))
        await rtk.approve(governor.address, toWei("500"))
        await rtk.approve(governor.address, toWei("500"))

        console.log(fromWei(await governor.earned(user1.address)));
        await governor.connect(user1).getReward();

        console.log(fromWei(await rtk.balanceOf(user1.address)));
    })


    it("delegate", async () => {
        await governor.setRewardDistribution(user0.address);

        await stk.mint(user1.address, toWei("1000"));
        await stk.connect(user1).approve(governor.address, toWei("10000"));

        await governor.connect(user1).stake(toWei("1000"));
        expect(await governor.getDelegate(user1.address)).to.equal(user1.address);
        expect(await governor.getVoteBalance(user1.address)).to.equal(toWei("1000"));

        await governor.delegate(user2.address);
        expect(await governor.getDelegate(user1.address)).to.equal(user2.address);
    })
})
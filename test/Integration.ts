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

    let stk;
    let rtk;
    let governor;
    let target;

    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }

    const fromState = (state) => {
        return ProposalState[state]
    }

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
        governor = await createContract("TestLPGovernor");
        target = await createContract("MockLiquidityPool");

        console.table([
            ["STK", stk.address],
            ["RTK", rtk.address],
            ["Target", target.address],
            ["LPGovernor", governor.address],
        ])

        await stk.initialize("STK", "STK", user0.address);
        await governor.initialize(target.address, stk.address, rtk.address);
    });

    const skipBlock = async (num) => {
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    it("integration - vote::pass", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await stk.connect(user1).approve(governor.address, toWei("10000"));
        await governor.connect(user1).stake(toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));
        await stk.connect(user2).approve(governor.address, toWei("10000"));
        await governor.connect(user2).stake(toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        console.log("Proposal", pid.toString());
        console.log(fromState(await governor.state(pid)));
        await skipBlock(2);
        console.log(fromState(await governor.state(pid)));
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        await governor.execute(pid);
        console.log(fromState(await governor.state(pid)));
    })

    it("integration - vote::rejected", async () => {
        await stk.mint(user1.address, toWei("1000"));
        await stk.connect(user1).approve(governor.address, toWei("10000"));
        await governor.connect(user1).stake(toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));
        await stk.connect(user2).approve(governor.address, toWei("10000"));
        await governor.connect(user2).stake(toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        await skipBlock(2);
        console.log("Proposal", pid.toString());
        const tx = await governor.connect(user2).castVote(pid, false);
        console.log(await tx.wait())

        console.log(fromState(await governor.state(pid)));
        await skipBlock(2);
        console.log(fromState(await governor.state(pid)));
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        await skipBlock(20);
        console.log(fromState(await governor.state(pid)));
        await expect(governor.execute(pid)).to.be.revertedWith("proposal can only be executed if it is success and queued")
        console.log(fromState(await governor.state(pid)));
    })
})
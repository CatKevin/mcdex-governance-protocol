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
        governor = await createContract("TestLPGovernor");

        // console.table([
        //     ["STK", stk.address],
        //     ["RTK", rtk.address],
        //     ["Timelock", timelock.address],
        //     ["LPGovernor", governor.address],
        // ])

        await stk.initialize("STK", "STK", user0.address);
        await governor.initialize(stk.address, rtk.address, timelock.address, user0.address);
    });

    const skipBlock = async (num) => {
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    it("integration", async () => {
        const target = await createContract("MockLiquidityPool");

        await stk.mint(user1.address, toWei("1000"));
        await stk.connect(user1).approve(governor.address, toWei("10000"));
        await governor.connect(user1).stake(toWei("1000"));

        await stk.mint(user2.address, toWei("1000"));
        await stk.connect(user2).approve(governor.address, toWei("10000"));
        await governor.connect(user2).stake(toWei("1000"));

        let pid = await governor.connect(user1).callStatic.propose(
            [target.address],
            [0],
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );

        let tx2 = await governor.connect(user1).propose(
            [target.address],
            [0],
            ["setFastCreationEnabled(bool)"],
            ["0x0000000000000000000000000000000000000000000000000000000000000001"],
            "setFastCreationEnabled to true"
        );
        console.log(await governor.state(pid));
        await skipBlock(2);
        console.log(await governor.state(pid));
        console.log(fromWei((await governor.proposals(1)).forVotes))
    })
})
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

        console.log("user0", user0.address)
        console.log("user1", user1.address)
        console.log("user2", user2.address)
        console.log("user3", user3.address)
    })

    const skipBlock = async (num) => {
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    it("sell", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        await mcb.mint(user1.address, toWei("100"));
        await mcb.connect(user1).approve(seller.address, toWei("100"));

        await seller.connect(user1).covertToUSD(toWei("100"));
        expect(await mcb.balanceOf(user1.address)).to.equal(0)
        expect(await usd.balanceOf(user1.address)).to.equal(toWei("500"))
    })

    it("valueCapture - 6", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 6]);

        console.log("mcb", mcb.address)
        console.log("usd", usd.address)


        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        const valueCapture = await createContract("ValueCapture", [user1.address, user0.address]);
        await valueCapture.setUSDToken(usd.address, 6);
        await valueCapture.setUSDConverter(mcb.address, seller.address);

        await mcb.mint(valueCapture.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("100"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(user1.address)).to.equal(toWei("0"));

        await valueCapture.collectToken(mcb.address);

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(user1.address)).to.equal("500000000");
        expect(await valueCapture.getCapturedUSD()).to.equal(toWei("500"))
    })

    it("valueCapture - 18", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        console.log("mcb", mcb.address)
        console.log("usd", usd.address)

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        const valueCapture = await createContract("ValueCapture", [user1.address, user0.address]);
        await valueCapture.setUSDToken(usd.address, 18);
        await valueCapture.setUSDConverter(mcb.address, seller.address);

        await mcb.mint(valueCapture.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("100"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(user1.address)).to.equal(toWei("0"));

        await valueCapture.collectToken(mcb.address);

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(user1.address)).to.equal(toWei("500"));
        expect(await valueCapture.getCapturedUSD()).to.equal(toWei("500"))
    })
})
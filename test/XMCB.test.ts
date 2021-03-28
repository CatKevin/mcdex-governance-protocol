import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('XMCB', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let auth;
    let rtk;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];

        auth = await createContract("Authenticator");
        await auth.initialize();
    })

    const skipBlock = async (num) => {
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    it("mcb <=> xmcb", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(auth.address, mcb.address, toWei("0.05"));

        await mcb.mint(user1.address, toWei("100"));
        await mcb.mint(user2.address, toWei("100"));
        await mcb.connect(user1).approve(xmcb.address, toWei("1000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("1000"));

        await xmcb.connect(user1).deposit(toWei("100"));
        await xmcb.connect(user2).deposit(toWei("100"));

        expect(await xmcb.balanceOf(user1.address)).to.equal(toWei("100"))
        expect(await xmcb.balanceOf(user2.address)).to.equal(toWei("100"))
        expect(await xmcb.rawBalanceOf(user1.address)).to.equal(toWei("100"))
        expect(await xmcb.rawBalanceOf(user2.address)).to.equal(toWei("100"))
        expect(await xmcb.totalSupply()).to.equal(toWei("200"))

        await xmcb.connect(user1).withdraw(toWei("100"));
        expect(await mcb.balanceOf(user1.address)).to.equal(toWei("95"))

        expect(await xmcb.balanceOf(user1.address)).to.equal(toWei("0"))
        expect(await xmcb.balanceOf(user2.address)).to.equal(toWei("105"))
        expect(await xmcb.rawBalanceOf(user1.address)).to.equal(toWei("0"))
        expect(await xmcb.rawBalanceOf(user2.address)).to.equal(toWei("100"))
        expect(await xmcb.totalSupply()).to.equal(toWei("105"))

        await mcb.mint(user1.address, toWei("10"));

        await xmcb.connect(user1).deposit(toWei("105"));

        expect(await xmcb.balanceOf(user1.address)).to.equal(toWei("105"))
        expect(await xmcb.balanceOf(user2.address)).to.equal(toWei("105"))
        expect(await xmcb.rawBalanceOf(user1.address)).to.equal(toWei("100"))
        expect(await xmcb.rawBalanceOf(user2.address)).to.equal(toWei("100"))
        expect(await xmcb.totalSupply()).to.equal(toWei("210"))
    })
})
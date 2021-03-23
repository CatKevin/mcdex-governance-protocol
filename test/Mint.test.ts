import { expect } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('Minter', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let seriesA;
    let vault;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        seriesA = accounts[4];
        vault = accounts[5];
    })

    it("constructor", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");
        await expect(createContract("TestMinter", [
            user0.address,
            valueCapture.address,
            user2.address,
            toWei("0.25"),
            1000,
            {
                recipient: vault.address,
                releaseRate: toWei("0.2"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
            {
                recipient: seriesA.address,
                releaseRate: toWei("0.55392"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
        ])).to.be.revertedWith("token must be contract");

        await expect(createContract("TestMinter", [
            mcb.address,
            user0.address,
            user2.address,
            toWei("0.25"),
            1000,
            {
                recipient: vault.address,
                releaseRate: toWei("0.2"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
            {
                recipient: seriesA.address,
                releaseRate: toWei("0.55392"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
        ])).to.be.revertedWith("value capture must be contract");
    })

    it("mint - no caputre value", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");

        const minter = await createContract("TestMinter", [
            mcb.address,
            valueCapture.address,
            user2.address,
            toWei("0.25"),
            1000,
            {
                recipient: vault.address,
                releaseRate: toWei("0.2"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
            {
                recipient: seriesA.address,
                releaseRate: toWei("0.55392"),
                mintableAmount: 0,
                mintedAmount: 0,
                totalSupply: toWei("50000000")
            },
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("0"))

        await minter.setBlockNumber(1000)
        var toVault = await minter.toVault();
        var toSeriesA = await minter.toVault();
        expect(toVault.mintableAmount).to.equal(toWei("0"))
        expect(toSeriesA.mintableAmount).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("0"))


        await minter.setBlockNumber(1001)
        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("0.2"))

        await minter.setBlockNumber(1010)
        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("2"))

        await minter.setBlockNumber(1010)
        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("2"))

        await valueCapture.setCapturedUSD(toWei("0.4"));
        await minter.setBlockNumber(1001)
        expect(await minter.callStatic.getMintableAmountToSeriesA()).to.equal(toWei("0.2"))
        expect(await minter.callStatic.getMintableAmountToVault()).to.equal(toWei("0.4"))
    })

    // it("amount", async () => {
    //     const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    //     const valueCapture = await createContract("TestValueCapture");

    //     const minter = await createContract("TestMinter", [
    //         mcb.address,
    //         valueCapture.address,
    //         user2.address,
    //         toWei("0.25"),
    //         toWei("10000000"),
    //         0,
    //         toWei("86400") // 1 persecond
    //     ]);
    //     await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

    //     await minter.setTimestamp(1000)
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("1000"))
    //     expect(await minter.mintedMCBToken()).to.equal(toWei("0"))
    //     await minter.mintMCBToken(user0.address, toWei("1000"));
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("0"))
    //     expect(await minter.mintedMCBToken()).to.equal(toWei("1000"))
    //     await expect(minter.mintMCBToken(user1.address, toWei("1000"))).to.be.revertedWith("exceeds mintable amount")

    //     await minter.setTimestamp(2000)
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("1000"))
    //     await minter.mintMCBToken(user0.address, toWei("1000"));
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("0"))
    //     expect(await minter.mintedMCBToken()).to.equal(toWei("2000"))

    //     await minter.setTimestamp(toWei("10000000"))
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("9998000"))
    //     await expect(minter.mintMCBToken(user0.address, toWei("9998001"))).to.be.revertedWith("exceeds mintable amount");

    //     await minter.setTimestamp(toWei("10001000"))
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("9998000")) // no more incremental
    // })


    // it("change dev account", async () => {
    //     const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    //     const valueCapture = await createContract("TestValueCapture");
    //     const minter = await createContract("TestMinter", [
    //         mcb.address,
    //         valueCapture.address,
    //         user2.address,
    //         toWei("0.25"),
    //         toWei("10000000"),
    //         0,
    //         toWei("86400") // 1 persecond
    //     ]);
    //     await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

    //     await minter.setTimestamp(1000)
    //     expect(await minter.mintableMCBToken()).to.equal(toWei("1000"))

    //     await minter.mintMCBToken(user0.address, toWei("100"));
    //     expect(await mcb.balanceOf(user0.address)).to.equal(toWei("75"));
    //     expect(await mcb.balanceOf(user2.address)).to.equal(toWei("25"));

    //     await minter.connect(user2).setDevAccount(user3.address);

    //     await minter.mintMCBToken(user0.address, toWei("100"));
    //     expect(await mcb.balanceOf(user0.address)).to.equal(toWei("150"));
    //     expect(await mcb.balanceOf(user2.address)).to.equal(toWei("25"));
    //     expect(await mcb.balanceOf(user3.address)).to.equal(toWei("25"));

    //     await expect(minter.setDevAccount(user3.address)).to.be.revertedWith("caller must be dev account")
    //     await expect(minter.connect(user3).setDevAccount(user3.address)).to.be.revertedWith("already dev account")
    // })
})
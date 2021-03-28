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
    })

    it("constructor", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");

        // address mcbToken_,
        // address valueCapture_,
        // address seriesA_,
        // address devAccount_,
        // uint256 baseMaxSupply_,
        // uint256 seriesAMaxSupply_,
        // uint256 baseMinReleaseRate_,
        // uint256 seriesAMaxReleaseRate_

        await expect(createContract("TestMinter", [
            user0.address,
            valueCapture.address,
            seriesA.address,
            user2.address,
            toWei("50000000"),
            toWei("50000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ])).to.be.revertedWith("token must be contract");

        await expect(createContract("TestMinter", [
            mcb.address,
            user0.address,
            seriesA.address,
            user2.address,
            toWei("50000000"),
            toWei("50000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ])).to.be.revertedWith("value capture must be contract");
    })

    it("mint - no caputre value", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");

        const minter = await createContract("TestMinter", [
            mcb.address,
            valueCapture.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0"))

        await minter.setBlockNumber(1)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0.2"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("2"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("2"))

        await valueCapture.setCapturedUSD(toWei("0.4"));  // min = 0.2 extra = 0.2
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0.2"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0.2"))

        await valueCapture.setCapturedUSD(toWei("1.0"));  // min 0.2 + extra1 0.55392 + extra2 (1-0.2-0.55392)
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0.55392"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0.44608"))
    })

    it("mint - base -> series-a -> base", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");

        const minter = await createContract("TestMinter", [
            mcb.address,
            valueCapture.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.5"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0"))

        await valueCapture.setCapturedUSD(toWei("6000000"));
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0.5"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("5000000"))
        // await minter.updateMintableAmount();
        // expect(await minter.callStatic.totalCapturedValue()).to.equal(toWei("6000000"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("5"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("5000000"))

        await valueCapture.setCapturedUSD(toWei("8000000"));
        await minter.setBlockNumber(10000000)
        // extra = 8000000 - 20000000 = 6000000
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("5000000"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("3000000"))

        await valueCapture.setCapturedUSD(toWei("1"));
        await minter.setBlockNumber(1)
        await minter.updateMintableAmount();
        // 0.8 - 0.5 
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0.5"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0.5")) // 0.2 + 0.3
        expect(await minter.callStatic.extraMintableAmount()).to.equal(toWei("0.3"))

        await minter.setBlockNumber(2)
        await minter.updateSeriesAMintableAmount();
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0.8"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0.4")) // 0.2 + 0.3
        expect(await minter.callStatic.extraMintableAmount()).to.equal(toWei("0"))
    })

    it("change dev account", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const valueCapture = await createContract("TestValueCapture");
        const minter = await createContract("TestMinter", [
            mcb.address,
            valueCapture.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(10000) // mintable = 2000 

        await minter.mint(user0.address, toWei("100"));
        expect(await mcb.balanceOf(user0.address)).to.equal(toWei("75"));
        expect(await mcb.balanceOf(user2.address)).to.equal(toWei("25"));

        await minter.connect(user2).setDevAccount(user3.address);

        await minter.mint(user0.address, toWei("100"));
        expect(await mcb.balanceOf(user0.address)).to.equal(toWei("150"));
        expect(await mcb.balanceOf(user2.address)).to.equal(toWei("25"));
        expect(await mcb.balanceOf(user3.address)).to.equal(toWei("25"));

        await expect(minter.setDevAccount(user3.address)).to.be.revertedWith("caller must be dev account")
        await expect(minter.connect(user3).setDevAccount(user3.address)).to.be.revertedWith("already dev account")
    })
})
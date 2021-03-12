import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('ValueCapture', () => {
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

    it("token whitelist", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd2 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd3 = await createContract("CustomERC20", ["USD", "USD", 6]);

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(user1.address, user0.address)
        await valueCapture.setGuardian(user0.address);

        expect(await valueCapture.getUSDTokenCount()).to.equal(0)
        var result = await valueCapture.getAllUSDTokens();
        expect(result.length).to.equal(0)

        await valueCapture.setUSDToken(usd1.address, 18);
        expect(await valueCapture.getUSDTokenCount()).to.equal(1)
        var result = await valueCapture.getAllUSDTokens();
        expect(result.length).to.equal(1)

        await valueCapture.setUSDToken(usd2.address, 18);
        await valueCapture.setUSDToken(usd3.address, 6);
        expect(await valueCapture.getUSDTokenCount()).to.equal(3)
        var result = await valueCapture.getAllUSDTokens();
        expect(result.length).to.equal(3)
        expect(result[0]).to.equal(usd1.address)
        expect(result[1]).to.equal(usd2.address)
        expect(result[2]).to.equal(usd3.address)

        expect(await valueCapture.getUSDToken(0)).to.equal(usd1.address)
        expect(await valueCapture.getUSDToken(1)).to.equal(usd2.address)
        expect(await valueCapture.getUSDToken(2)).to.equal(usd3.address)

        var props = await valueCapture.getUSDTokenInfo(usd1.address);
        expect(props[0]).to.equal(1)
        expect(props[1]).to.equal(0)

        await valueCapture.unsetUSDToken(usd2.address);
        var result = await valueCapture.getAllUSDTokens();
        expect(result.length).to.equal(2)
        expect(result[0]).to.equal(usd1.address)
        expect(result[1]).to.equal(usd3.address)

        await expect(valueCapture.unsetUSDToken(usd2.address)).to.be.revertedWith("token not in usd list")
        await expect(valueCapture.setUSDToken(usd2.address, 19)).to.be.revertedWith("decimals out of range")
        await expect(valueCapture.setUSDToken(usd2.address, 17)).to.be.revertedWith("decimals not match")
        await expect(valueCapture.setUSDToken(user0.address, 18)).to.be.revertedWith("token address must be contract")
        await expect(valueCapture.setUSDToken(usd1.address, 18)).to.be.revertedWith("token already in usd list")
    })

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

        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(user1.address, user0.address)
        await valueCapture.setGuardian(user0.address);

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
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("500"))
    })

    it("valueCapture - 18", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(user1.address, user0.address)
        await valueCapture.setGuardian(user0.address);

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
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("500"))
    })

    it("collect preset assets", async () => {

        const vault = await createContract("Vault");

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(vault.address, user0.address)
        await valueCapture.setGuardian(user0.address);

        const erc20 = await createContract("CustomERC20", ["ERC", "ERC", 18]);
        await erc20.mint(valueCapture.address, toWei("100"));

        await valueCapture.collectERC20Token(erc20.address, toWei("100"))
        expect(await erc20.balanceOf(valueCapture.address)).to.equal(0)
        expect(await erc20.balanceOf(vault.address)).to.equal(toWei("100"))

        const erc721 = await createContract("CustomERC721", ["ERC721", "ERC721"])
        await erc721.mint(valueCapture.address, 1);
        await erc721.mint(valueCapture.address, 2);
        await valueCapture.collectERC721Token(erc721.address, 1);

        expect(await erc721.balanceOf(valueCapture.address)).to.equal(1)
        expect(await erc721.balanceOf(vault.address)).to.equal(1)
        expect(await erc721.ownerOf(1)).to.equal(vault.address)
        expect(await erc721.ownerOf(2)).to.equal(valueCapture.address)

        await user0.sendTransaction({
            to: valueCapture.address,
            value: toWei("1")
        });
        expect(await ethers.provider.getBalance(valueCapture.address)).to.equal(toWei("1"))

        expect(await ethers.provider.getBalance(vault.address)).to.equal(toWei("0"))
        await valueCapture.collectNativeCurrency(toWei("1"));
        expect(await ethers.provider.getBalance(vault.address)).to.equal(toWei("1"))

    })

    it("collect usd", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(user1.address, user0.address)
        await valueCapture.setGuardian(user0.address);
        await expect(valueCapture.setGuardian(user0.address)).to.be.revertedWith("new guardian is already guardian")

        await valueCapture.setUSDToken(usd.address, 18);

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        // await valueCapture.setUSDConverter(mcb.address, seller.address);
        // await usd.mint(seller.address, toWei("10000"));

        expect(await valueCapture.totalCapturedUSD()).to.equal(0)

        // no converter
        await mcb.mint(valueCapture.address, toWei("100"))
        await expect(valueCapture.collectToken(mcb.address)).to.be.revertedWith("token has no converter")

        // usd
        await usd.mint(valueCapture.address, toWei("100"))
        await valueCapture.collectToken(usd.address);
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("100"))

        await expect(valueCapture.collectToken(usd.address)).to.be.revertedWith("no balance to convert")
        await expect(valueCapture.connect(user1).collectToken(usd.address)).to.be.revertedWith("caller must be guardian")
    })


    it("converter", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(user1.address, user0.address)
        await valueCapture.setGuardian(user0.address);

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await expect(valueCapture.setUSDConverter(mcb.address, seller.address)).to.be.revertedWith("token out not in list")
        await expect(valueCapture.setUSDConverter(mcb.address, user0.address)).to.be.revertedWith("converter must be contract")
    });
})
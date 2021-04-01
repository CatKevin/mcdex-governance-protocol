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
    let vault;
    let auth;
    let dataExchange;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        vault = accounts[3];

        auth = await createContract("Authenticator");
        await auth.initialize();

        dataExchange = await createContract("MockDataExchange");
    })

    it("token whitelist", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd2 = await createContract("CustomERC20", ["USD", "USD", 18]);
        const usd3 = await createContract("CustomERC20", ["USD", "USD", 6]);

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)

        var tokens = await valueCapture.listUSDTokens(0, 100);
        expect(tokens.length).to.equal(0)

        await valueCapture.addUSDToken(usd1.address, 18);
        var tokens = await valueCapture.listUSDTokens(0, 100);
        expect(tokens.length).to.equal(1)
        expect(tokens[0]).to.equal(usd1.address);

        await valueCapture.addUSDToken(usd2.address, 18);
        await valueCapture.addUSDToken(usd3.address, 6);
        var tokens = await valueCapture.listUSDTokens(0, 100);
        expect(tokens.length).to.equal(3)
        expect(tokens[0]).to.equal(usd1.address)
        expect(tokens[1]).to.equal(usd2.address)
        expect(tokens[2]).to.equal(usd3.address)

        await valueCapture.removeUSDToken(usd2.address);
        var tokens = await valueCapture.listUSDTokens(0, 100);
        expect(tokens.length).to.equal(2)
        expect(tokens[0]).to.equal(usd1.address)
        expect(tokens[1]).to.equal(usd3.address)

        await expect(valueCapture.removeUSDToken(usd2.address)).to.be.revertedWith("token not in usd list")
        await expect(valueCapture.addUSDToken(usd2.address, 19)).to.be.revertedWith("decimals out of range")
        await expect(valueCapture.addUSDToken(usd2.address, 17)).to.be.revertedWith("decimals not match")
        await expect(valueCapture.addUSDToken(user0.address, 18)).to.be.revertedWith("token address must be contract")
        await expect(valueCapture.addUSDToken(usd1.address, 18)).to.be.revertedWith("token already in usd list")
    })

    it("converter", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        await mcb.mint(user1.address, toWei("100"));
        await mcb.connect(user1).approve(seller.address, toWei("100"));

        await seller.connect(user1).exchange(toWei("100"));
        expect(await mcb.balanceOf(user1.address)).to.equal(0)
        expect(await usd.balanceOf(user1.address)).to.equal(toWei("500"))
    })

    it("valueCapture - 6", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 6]);
        const oracle = await createContract("MockTWAPOracle");
        await oracle.setPrice(toWei("5"));

        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)

        await valueCapture.addUSDToken(usd.address, 6);
        await valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("0.01")); // 1%

        await mcb.mint(valueCapture.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("100"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal(toWei("0"));

        await valueCapture.forwardAsset(mcb.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal("500000000");
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("500"))
        expect(await dataExchange.getTotalCapturedUSD()).to.equal(toWei("500"))
    })

    it("valueCapture - 18", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const oracle = await createContract("MockTWAPOracle");
        await oracle.setPrice(toWei("5"));


        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)
        await valueCapture.addUSDToken(usd.address, 18);

        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));
        await valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("0.01")); // 1%

        await mcb.mint(valueCapture.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("100"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal(toWei("0"));

        await valueCapture.forwardAsset(mcb.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal(toWei("500"));
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("500"))
        expect(await dataExchange.getTotalCapturedUSD()).to.equal(toWei("500"))
    })

    it("valueCapture - admin", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const oracle = await createContract("MockTWAPOracle");
        await oracle.setPrice(toWei("5"));

        await auth.grantRole(ethers.utils.id("VALUE_CAPTURE_ADMIN_ROLE"), user2.address);

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)
        await expect(valueCapture.connect(user1).addUSDToken(usd.address, 18)).to.be.revertedWith("not authorized");
        await valueCapture.connect(user2).addUSDToken(usd.address, 18);

        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await usd.mint(seller.address, toWei("10000"));
        await valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("0.01")); // 1%

        await mcb.mint(valueCapture.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("100"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal(toWei("0"));

        await valueCapture.forwardAsset(mcb.address, toWei("100"));

        expect(await mcb.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(valueCapture.address)).to.equal(toWei("0"));
        expect(await usd.balanceOf(vault.address)).to.equal(toWei("500"));
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("500"))
        expect(await dataExchange.getTotalCapturedUSD()).to.equal(toWei("500"))
    })

    it("forward preset assets", async () => {
        const vault = await createContract("Vault");

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)

        const erc20 = await createContract("CustomERC20", ["ERC", "ERC", 18]);
        await erc20.mint(valueCapture.address, toWei("100"));

        await valueCapture.forwardERC20Token(erc20.address, toWei("100"))
        expect(await erc20.balanceOf(valueCapture.address)).to.equal(0)
        expect(await erc20.balanceOf(vault.address)).to.equal(toWei("100"))

        const erc721 = await createContract("CustomERC721", ["ERC721", "ERC721"])
        await erc721.mint(valueCapture.address, 1);
        await erc721.mint(valueCapture.address, 2);
        await valueCapture.forwardERC721Token(erc721.address, 1);

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
        await valueCapture.forwardETH(toWei("1"));
        expect(await ethers.provider.getBalance(vault.address)).to.equal(toWei("1"))
    })

    it("exception - forward", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const oracle = await createContract("MockTWAPOracle");

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)

        await valueCapture.addUSDToken(usd.address, 18);

        expect(await valueCapture.totalCapturedUSD()).to.equal(0)

        // no converter
        await mcb.mint(valueCapture.address, toWei("100"))
        await expect(valueCapture.forwardAsset(mcb.address, toWei("0"))).to.be.revertedWith("amount in is zero")

        // usd
        await usd.mint(valueCapture.address, toWei("100"))
        await valueCapture.forwardAsset(usd.address, toWei("100"));
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("100"))

        // 1e18 mcb = 5e6 usd
        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("4.94")])
        await usd.mint(seller.address, toWei("10000"));
        await mcb.mint(valueCapture.address, toWei("100"));
        await valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("0.01")); // 1%

        await oracle.setPrice(toWei("5"));
        await expect(valueCapture.forwardAsset(mcb.address, toWei("100"))).to.be.revertedWith("slippage exceeds tolerance")

        await oracle.setPrice(toWei("4.98"));
        await valueCapture.forwardAsset(mcb.address, toWei("100"));
    })


    it("exception - convertor", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const oracle = await createContract("MockTWAPOracle");

        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(auth.address, dataExchange.address, vault.address)

        const seller = await createContract("ConstantSeller", [mcb.address, usd.address, toWei("5")])
        await expect(valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("1.01"))).to.be.revertedWith("slippage tolerance is out of range")
        await expect(valueCapture.setConvertor(mcb.address, user0.address, seller.address, toWei("0.01"))).to.be.revertedWith("oracle must be a contract")
        await expect(valueCapture.setConvertor(mcb.address, oracle.address, user0.address, toWei("0.01"))).to.be.revertedWith("convertor must be a contract")
        await expect(valueCapture.setConvertor(mcb.address, oracle.address, seller.address, toWei("0.01"))).to.be.revertedWith("token out is not in usd list")
    });
})
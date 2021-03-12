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

    it("mcb <=> xmcb", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(user0.address, mcb.address, toWei("0.05"));

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

    it("mcb <=> xmcb", async () => {
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(user0.address, mcb.address, toWei("0.05"));

        await mcb.mint(user1.address, toWei("1000000"));
        await mcb.mint(user2.address, toWei("100"));
        await mcb.connect(user1).approve(xmcb.address, toWei("1000000000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("1000000000"));

        const tx = await xmcb.connect(user1).deposit(toWei("1000000"));
        await xmcb.connect(user2).deposit(toWei("100"));

        const timelock = await createContract("Timelock", [user0.address, 86400]);
        const governor = await createContract("GovernorAlpha", [timelock.address, xmcb.address, user0.address]);
        const vault = await createContract("Vault");
        await vault.initialize(timelock.address);
        await usd.mint(vault.address, toWei("10"));

        await governor.connect(user1).propose(
            [vault.address],
            [0],
            ["transferERC20(address,address,uint256)"],
            ["0x9db5dbe40000000000000000000000008a791620dd6260079bf849dc5567adc3f2fdc3180000000000000000000000003c44cdddb6a900fa2b585dd299e03d12fa4293bc0000000000000000000000000000000000000000000000008ac7230489e80000"],
            "proposal to transfer usd to user2"
        )

        // console.log(await governor.proposals(1));

        // console.log("mcb", mcb.address)
        // console.log("xmcb", xmcb.address)
        // console.log("vault", vault.address)
        // console.log("timelock", timelock.address)
        // console.log("governor", governor.address)
    })


    it("capture", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(user0.address, mcb.address, toWei("0.05"));
        const timelock = await createContract("TestTimelock", [user0.address, 86400]);
        const governor = await createContract("TestGovernorAlpha", [timelock.address, xmcb.address, user0.address]);

        var starttime = (await ethers.provider.getBlock()).timestamp;
        await timelock.skipTime(0);

        const eta = starttime + 86400 + 1;
        await timelock.queueTransaction(
            timelock.address,
            0,
            "setPendingAdmin(address)",
            ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
            eta
        )
        await timelock.skipTime(86400);
        await timelock.executeTransaction(
            timelock.address,
            0,
            "setPendingAdmin(address)",
            ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
            eta
        )
        await governor.__acceptAdmin();

        const vault = await createContract("Vault");
        await vault.initialize(timelock.address);
        const valueCapture = await createContract("ValueCapture");
        await valueCapture.initialize(vault.address, user0.address)
        await valueCapture.setGuardian(user0.address);

        const tokenIn1 = await createContract("CustomERC20", ["TKN1", "TKN1", 18]);
        const tokenIn2 = await createContract("CustomERC20", ["TKN2", "TKN2", 18]);
        const tokenIn3 = await createContract("CustomERC20", ["TKN3", "TKN3", 6]);

        const tokenOu1 = await createContract("CustomERC20", ["USD1", "USD1", 18]);
        const tokenOu2 = await createContract("CustomERC20", ["USD2", "USD2", 6]);

        // converter
        const seller1 = await createContract("ConstantSeller", [tokenIn1.address, tokenOu1.address, toWei("4")])
        const seller2 = await createContract("ConstantSeller", [tokenIn2.address, tokenOu2.address, toWei("4")])
        const seller3 = await createContract("ConstantSeller", [tokenIn3.address, tokenOu2.address, toWei("4")])

        await tokenOu1.mint(seller1.address, toWei("100000000000000"));
        await tokenOu2.mint(seller2.address, toWei("100000000000000"));
        await tokenOu2.mint(seller3.address, toWei("100000000000000"));

        // set converter
        await valueCapture.setUSDToken(tokenOu1.address, 18);
        await valueCapture.setUSDToken(tokenOu2.address, 6);

        await valueCapture.setUSDConverter(tokenIn1.address, seller1.address);
        await valueCapture.setUSDConverter(tokenIn2.address, seller2.address);
        await valueCapture.setUSDConverter(tokenIn3.address, seller3.address);

        // asset => valueCaputure
        await tokenIn1.mint(user1.address, toWei("1000000"));
        await tokenIn2.mint(user1.address, toWei("1000000"));
        await tokenIn3.mint(user1.address, toWei("1000000"));

        await tokenIn1.connect(user1).transfer(valueCapture.address, toWei("100"))  // 100
        await tokenIn2.connect(user1).transfer(valueCapture.address, toWei("200"))   // 200
        await tokenIn3.connect(user1).transfer(valueCapture.address, "300000000")   // 300

        // convert
        expect(await valueCapture.totalCapturedUSD()).to.equal(0);

        await valueCapture.collectToken(tokenIn1.address);
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("400"));
        await valueCapture.collectToken(tokenIn2.address);
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("1200"));
        await valueCapture.collectToken(tokenIn3.address);
        expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("2400"));

        // vault
        expect(await tokenOu1.balanceOf(vault.address)).to.equal(toWei("400"))
        expect(await tokenOu2.balanceOf(vault.address)).to.equal("2000000000")

        // proposal to transfer token back
        // mcb
        await mcb.mint(user1.address, toWei("1000000"));
        await mcb.mint(user2.address, toWei("100"));
        await mcb.connect(user1).approve(xmcb.address, toWei("1000000000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("1000000000"));

        // propose
        await xmcb.connect(user1).deposit(toWei("1000000"));

        // mock time
        var starttime = (await ethers.provider.getBlock()).timestamp;
        await governor.setTimestamp(starttime);
        await timelock.setTimestamp(starttime);

        await governor.connect(user1).propose(
            [vault.address],
            [0],
            ["transferERC20(address,address,uint256)"],
            [
                ethers.utils.defaultAbiCoder.encode(
                    ["address", "address", "uint256"],
                    [tokenOu1.address, user2.address, toWei("200")]
                )
            ],
            "proposal to transfer usd to user2"
        )
        await governor.skipBlock(1);
        await governor.connect(user1).castVote(1, true);
        expect(await governor.state(1)).to.equal(1);

        await governor.skipBlock(17280);
        expect(await governor.state(1)).to.equal(4);

        await timelock.skipTime(86400);
        await governor.skipTime(86400);
        await governor.queue(1);

        expect(await tokenOu1.balanceOf(user2.address)).to.equal(0)

        await timelock.skipTime(86400);
        await governor.skipTime(86400);
        await governor.execute(1);

        expect(await tokenOu1.balanceOf(user2.address)).to.equal(toWei("200"))
    })
})
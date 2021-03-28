import { expect } from "chai";
import { time } from "console";
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

        auth = await createContract("Authenticator");
        await auth.initialize();
    })

    const skipBlock = async (num) => {
        for (let i = 0; i < num; i++) {
            await rtk.approve(user3.address, 1);
        }
    }

    it("propose - defeated", async () => {
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(auth.address, mcb.address, toWei("0.05"));

        await mcb.mint(user1.address, toWei("1000000"));
        await mcb.mint(user2.address, toWei("100"));
        await mcb.connect(user1).approve(xmcb.address, toWei("1000000000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("1000000000"));

        await xmcb.connect(user1).deposit(toWei("1000000"));
        await xmcb.connect(user2).deposit(toWei("100"));

        const timelock = await createContract("Timelock", [user0.address, 86400]);
        const governor = await createContract("TestGovernorAlpha", [mcb.address, timelock.address, xmcb.address, user0.address]);
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
        var proposal = await governor.proposals(1);
        expect(proposal.quorumVotes).to.equal(toWei("100010"));


        expect(await governor.state(1)).to.be.equal(ProposalState.Pending);

        await governor.skipBlock(1);
        expect(await governor.state(1)).to.be.equal(ProposalState.Active);

        await governor.skipBlock(17280);
        expect(await governor.state(1)).to.be.equal(ProposalState.Defeated);
    })

    it("propose - Succeeded", async () => {
        const usd = await createContract("CustomERC20", ["USD", "USD", 18]);
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const xmcb = await createContract("XMCB");
        await xmcb.initialize(auth.address, mcb.address, toWei("0.05"));

        await mcb.mint(user1.address, toWei("1000"));
        await mcb.mint(user2.address, toWei("1000"));
        await mcb.connect(user1).approve(xmcb.address, toWei("1000000000"));
        await mcb.connect(user2).approve(xmcb.address, toWei("1000000000"));

        await xmcb.connect(user1).deposit(toWei("1000"));
        await xmcb.connect(user2).deposit(toWei("1000"));

        const timelock = await createContract("TestTimelock", [user0.address, 86400]);
        const governor = await createContract("TestGovernorAlpha", [mcb.address, timelock.address, xmcb.address, user0.address]);
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
        await timelock.skipTime(86400 + 1);
        await timelock.executeTransaction(
            timelock.address,
            0,
            "setPendingAdmin(address)",
            ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
            eta
        )
        await governor.__acceptAdmin();

        const vault = await createContract("Vault");
        await vault.initialize(auth.address);
        await auth.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", timelock.address);
        await usd.mint(vault.address, toWei("1000"));

        await governor.connect(user1).propose(
            [vault.address],
            [0],
            ["transferERC20(address,address,uint256)"],
            [ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256"], [usd.address, user2.address, toWei("10")])],
            "proposal to transfer usd to user2"
        )
        expect(await governor.state(1)).to.be.equal(ProposalState.Pending);

        await governor.skipBlock(1);
        await governor.skipTime(1);
        expect(await governor.state(1)).to.be.equal(ProposalState.Active);

        await governor.connect(user1).castVote(1, true);
        await governor.skipBlock(17280);
        expect(await governor.state(1)).to.be.equal(ProposalState.Succeeded);

        await timelock.setTimestamp(Math.floor(Date.now() / 1000) - 86400)
        await governor.queue(1);
        expect(await governor.state(1)).to.be.equal(ProposalState.Queued);

        await timelock.setTimestamp(Math.floor(Date.now() / 1000) + 86400 * 2)
        await governor.execute(1);
        expect(await governor.state(1)).to.be.equal(ProposalState.Executed);

        expect(await usd.balanceOf(user2.address)).to.equal(toWei("10"))

    })
})
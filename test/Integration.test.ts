import { expect } from "chai";
const { ethers } = require("hardhat");
import { toWei, fromWei, getAccounts } from "../scripts/utils";

import { Deployer } from "./TestDeployer";

describe("Integration", () => {
  let accounts;
  let user0;
  let user1;
  let user2;
  let user3;
  let developer;
  let vesting;

  let authenticator;
  let mcb;
  let xmcb;
  let valueCapture;
  let vault;
  let rewardDistribution;
  let mcbMinter;
  let timelock;
  let governor;
  let admin;
  let tm;

  const deployer = new Deployer();

  enum ProposalState {
    Pending,
    Active,
    Canceled,
    Defeated,
    Succeeded,
    Queued,
    Expired,
    Executed,
  }

  const fromState = (state) => {
    return ProposalState[state];
  };

  const blockTime = async () => {
    return (await ethers.provider.getBlock()).timestamp;
  };

  const blockNumber = async () => {
    return (await ethers.provider.getBlock()).number;
  };

  before(async () => {
    accounts = await getAccounts();
    admin = accounts[0];
    user0 = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];
    developer = accounts[5];
    vesting = accounts[9];
  });

  describe("scenario A", async () => {
    beforeEach(async () => {
      mcb = await deployer.deploy("MCB", "MCB", "MCB", 18);
      await mcb.mint(user1.address, toWei("2000000"));

      authenticator = await deployer.deploy("Authenticator");
      vault = await deployer.deploy("Vault");
      tm = await deployer.deploy("TimeMachine");

      xmcb = await deployer.deploy("TestXMCB", tm.address);
      valueCapture = await deployer.deploy("TestValueCapture", tm.address);
      timelock = await deployer.deploy("TestTimelock", tm.address);
      governor = await deployer.deploy("TestGovernorAlpha", tm.address);
      rewardDistribution = await deployer.deploy("TestRewardDistribution", tm.address);
      mcbMinter = await deployer.deploy("TestMCBMinter", tm.address);

      // initialize
      await authenticator.initialize();
      await xmcb.initialize(authenticator.address, mcb.address, toWei("0.05"));
      await vault.initialize(authenticator.address);

      await valueCapture.initialize(authenticator.address, vault.address);
      await valueCapture.setCaptureNotifyRecipient(mcbMinter.address);

      await rewardDistribution.initialize(authenticator.address, xmcb.address);

      await mcbMinter.initialize(
        authenticator.address,
        mcb.address,
        developer.address,
        800000,
        await mcb.totalSupply(),
        toWei("0.2")
      );
      await mcbMinter.newRound(vesting.address, toWei("700000"), toWei("0.55392"), 800000);

      await timelock.initialize(governor.address, 86400);
      await governor.initialize(mcb.address, timelock.address, xmcb.address, admin.address, 23);

      // roles
      await authenticator.grantRole(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        timelock.address
      );
      await authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ROLE"), valueCapture.address);
      await mcb.grantRole(ethers.utils.id("MINTER_ROLE"), mcbMinter.address);
    });

    it("forward && capture && mint", async () => {
      await authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ADMIN_ROLE"), user2.address);

      const usdc = await deployer.deploy("CustomERC20", "MCB", "MCB", 6);
      const dai = await deployer.deploy("CustomERC20", "MCB", "MCB", 18);
      await valueCapture.connect(user2).addUSDToken(usdc.address, 6);
      await valueCapture.connect(user2).addUSDToken(dai.address, 18);

      await usdc.mint(valueCapture.address, "1000000000"); // 1000 usdc
      await dai.mint(valueCapture.address, toWei("540")); // 540 dai

      await tm.turnOn();
      await tm.setBlockNumber(801000);

      await valueCapture.forwardMultiAssets([usdc.address, dai.address], ["1000000000", toWei("540")]);
      expect(await valueCapture.totalCapturedUSD()).to.equal(toWei("1540"));
      expect(await valueCapture.totalCapturedUSD()).to.equal(await mcbMinter.lastCapturedValue());
      expect(await valueCapture.lastCapturedBlock()).to.equal(await mcbMinter.lastCapturedBlock());

      await mcb.connect(user1).approve(xmcb.address, toWei("2000000"));
      await xmcb.connect(user1).deposit(toWei("200000"));

      await tm.skipBlock(3);
      await governor
        .connect(user1)
        .propose(
          [mcbMinter.address],
          [0],
          ["mintFromBase(address,uint256)"],
          [ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [user2.address, toWei("1000")])],
          "base mint to user0"
        );

      await tm.skipBlock(2);
      await governor.connect(user1).castVote(23, true);

      await tm.skipBlock(17280);
      expect(await governor.state(23)).to.equal(ProposalState.Succeeded);

      await governor.queue(23);
      await tm.skipTime(86400);

      console.log(fromWei((await mcbMinter.callStatic.getMintableAmounts())[0]));
      await governor.execute(23);
      expect(await mcb.balanceOf(user2.address)).to.equal(toWei("750"));
      expect(await mcb.balanceOf(developer.address)).to.equal(toWei("250"));
      console.log(fromWei((await mcbMinter.callStatic.getMintableAmounts())[0]));
    });

    it("initiate usdc farming", async () => {
      await authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ADMIN_ROLE"), user2.address);

      const usdc = await deployer.deploy("CustomERC20", "USDC", "USDC", 6);
      await usdc.mint(vault.address, toWei("20000"));

      await tm.turnOn();
      await tm.setBlockNumber(801000);

      await mcb.connect(user1).approve(xmcb.address, toWei("2000000"));
      await xmcb.connect(user1).deposit(toWei("200000"));

      await tm.skipBlock(3);
      await governor
        .connect(user1)
        .propose(
          [rewardDistribution.address, rewardDistribution.address, vault.address],
          [0, 0, 0],
          [
            "createRewardPlan(address,uint256)",
            "notifyRewardAmount(address,uint256)",
            "transferERC20(address,address,uint256)",
          ],
          [
            ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [usdc.address, toWei("0.2")]),
            ethers.utils.defaultAbiCoder.encode(["address", "uint256"], [usdc.address, toWei("20000")]),
            ethers.utils.defaultAbiCoder.encode(
              ["address", "address", "uint256"],
              [usdc.address, rewardDistribution.address, toWei("20000")]
            ),
          ],
          "usdc farming"
        );

      await tm.skipBlock(2);
      await governor.connect(user1).castVote(23, true);

      await tm.skipBlock(17280);
      expect(await governor.state(23)).to.equal(ProposalState.Succeeded);

      await governor.queue(23);
      await tm.skipTime(86400);

      await governor.execute(23);

      await tm.skipBlock("100");
      console.log(fromWei(await rewardDistribution.earned(usdc.address, user1.address)));

      await rewardDistribution.connect(user1).getAllRewards();
      console.log(fromWei(await rewardDistribution.earned(usdc.address, user1.address)));
    });
  });

  describe("scenario B", async () => {
    beforeEach(async () => {
      mcb = await deployer.deploy("MCB", "MCB", "MCB", 18);
      await mcb.mint(user1.address, "2193176548671886899345095");

      authenticator = await deployer.deploy("Authenticator");
      vault = await deployer.deploy("Vault");
      tm = await deployer.deploy("TimeMachine");

      xmcb = await deployer.deploy("TestXMCB", tm.address);
      valueCapture = await deployer.deploy("TestValueCapture", tm.address);
      timelock = await deployer.deploy("TestTimelock", tm.address);
      governor = await deployer.deploy("TestGovernorAlpha", tm.address);
      rewardDistribution = await deployer.deploy("TestRewardDistribution", tm.address);
      mcbMinter = await deployer.deploy("TestMCBMinter", tm.address);

      // initialize
      await authenticator.initialize();
      await xmcb.initialize(authenticator.address, mcb.address, toWei("0.05"));
      await vault.initialize(authenticator.address);

      await valueCapture.initialize(authenticator.address, vault.address);
      await valueCapture.setCaptureNotifyRecipient(mcbMinter.address);

      await rewardDistribution.initialize(authenticator.address, xmcb.address);

      await mcbMinter.initialize(
        authenticator.address,
        mcb.address,
        developer.address,
        800000,
        await mcb.totalSupply(),
        ethers.BigNumber.from("200000000000000000")
      );

      console.log(ethers.BigNumber.from("933333333333333333333333"));

      await mcbMinter.newRound(
        vesting.address,
        ethers.BigNumber.from("933333333333333333333333"),
        ethers.BigNumber.from("694444444444444444"),
        800000
      );

      await timelock.initialize(governor.address, 86400);
      await governor.initialize(mcb.address, timelock.address, xmcb.address, admin.address, 23);

      // roles
      await authenticator.grantRole(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        timelock.address
      );
      await authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ROLE"), valueCapture.address);
      await mcb.grantRole(ethers.utils.id("MINTER_ROLE"), mcbMinter.address);
    });

    it("seriesA - release all", async () => {
      await authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ADMIN_ROLE"), user2.address);
      const usdc = await deployer.deploy("CustomERC20", "USDC", "USDC", 6);
      await valueCapture.connect(user2).addUSDToken(usdc.address, 6);
      await usdc.mint(valueCapture.address, "1000000000000000"); // enough to release all

      await tm.turnOn();
      await tm.setBlockNumber(2145000);

      await valueCapture.forwardMultiAssets([usdc.address], ["1000000000000000"]);

      console.log((await mcbMinter.callStatic.getMintableAmounts())[1].toString());

      await expect(mcbMinter.mintFromRound(1)).to.be.revertedWith("round not exists");
      await mcbMinter.mintFromRound(0);

      console.log(fromWei(await mcb.balanceOf(vesting.address)));
      console.log(fromWei(await mcb.balanceOf(developer.address)));

      console.log((await mcbMinter.callStatic.getMintableAmounts())[1].toString());

      await tm.setBlockNumber(2147000);
    });
  });
});

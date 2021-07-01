import { expect } from "chai";
import { toWei, fromWei, toBytes32, getAccounts, createContract } from "../scripts/utils";

describe("Minging", () => {
  let accounts;
  let user0;
  let user1;
  let user2;
  let user3;
  let auth;

  before(async () => {
    accounts = await getAccounts();
    user0 = accounts[0];
    user1 = accounts[1];
    user2 = accounts[2];
    user3 = accounts[3];

    auth = await createContract("Authenticator");
    await auth.initialize();
  });

  it("mining list", async () => {
    const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
    const usd2 = await createContract("CustomERC20", ["USD", "USD", 6]);

    const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    const xmcb = await createContract("XMCB");
    await xmcb.initialize(auth.address, mcb.address, toWei("0.05"));

    const tm = await createContract("TimeMachine");

    const rewardDistribution1 = await createContract("TestRewardDistribution", [tm.address]);
    await rewardDistribution1.initialize(auth.address, xmcb.address);

    const rewardDistribution2 = await createContract("TestRewardDistribution", [tm.address]);
    await rewardDistribution2.initialize(auth.address, xmcb.address);

    await xmcb.addComponent(rewardDistribution1.address);
    await xmcb.addComponent(rewardDistribution2.address);

    expect(await xmcb.componentCount()).to.equal(2);
    var list = await xmcb.listComponents(0, 10);
    expect(list.length).to.equal(2);
    expect(list[0]).to.equal(rewardDistribution1.address);
    expect(list[1]).to.equal(rewardDistribution2.address);

    var list = await xmcb.listComponents(1, 2);
    expect(list.length).to.equal(1);
    expect(list[0]).to.equal(rewardDistribution2.address);

    var list = await xmcb.listComponents(2, 3);
    expect(list.length).to.equal(0);

    await xmcb.removeComponent(rewardDistribution1.address);
    expect(await xmcb.componentCount()).to.equal(1);
    var list = await xmcb.listComponents(0, 10);
    expect(list.length).to.equal(1);
    expect(list[0]).to.equal(rewardDistribution2.address);

    await expect(xmcb.removeComponent(rewardDistribution1.address)).to.be.revertedWith("component not exists");
    await expect(xmcb.addComponent(rewardDistribution2.address)).to.be.revertedWith("component already exists");
    await expect(xmcb.addComponent(mcb.address)).to.be.revertedWith("reverted");
  });

  it("mining", async () => {
    const usd1 = await createContract("CustomERC20", ["USD", "USD", 18]);
    const usd2 = await createContract("CustomERC20", ["USD", "USD", 6]);

    const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
    const xmcb = await createContract("XMCB");
    await xmcb.initialize(auth.address, mcb.address, toWei("0.05"));

    const tm = await createContract("TimeMachine");

    const rewardDistribution = await createContract("TestRewardDistribution", [tm.address]);
    await rewardDistribution.initialize(auth.address, xmcb.address);
    await xmcb.addComponent(rewardDistribution.address);

    await mcb.mint(user1.address, toWei("10000"));
    await mcb.mint(user2.address, toWei("10000"));
    await usd1.mint(rewardDistribution.address, toWei("10000"));
    await usd2.mint(rewardDistribution.address, toWei("10000"));
    await mcb.connect(user1).approve(xmcb.address, toWei("10000"));
    await mcb.connect(user2).approve(xmcb.address, toWei("10000"));

    await xmcb.connect(user1).deposit(toWei("100"));
    await xmcb.connect(user2).deposit(toWei("100"));

    await tm.turnOn();

    await rewardDistribution.createRewardPlan(usd1.address, toWei("2"));
    await rewardDistribution.createRewardPlan(usd2.address, "3000000");

    // usd1 start
    await rewardDistribution.notifyRewardAmount(usd1.address, toWei("20000"));
    await tm.skipBlock(1);
    expect(await rewardDistribution.earned(usd1.address, user1.address)).to.equal(toWei("1"));
    expect(await rewardDistribution.earned(usd1.address, user2.address)).to.equal(toWei("1"));

    await tm.skipBlock(2);
    expect(await rewardDistribution.earned(usd1.address, user1.address)).to.equal(toWei("3"));
    expect(await rewardDistribution.earned(usd1.address, user2.address)).to.equal(toWei("3"));

    await xmcb.connect(user2).withdraw(toWei("100"));
    await tm.skipBlock(1);
    expect(await rewardDistribution.earned(usd1.address, user1.address)).to.equal(toWei("5"));
    expect(await rewardDistribution.earned(usd1.address, user2.address)).to.equal(toWei("3"));

    await xmcb.connect(user2).deposit(toWei("105"));
    await tm.skipBlock(1);
    expect(await rewardDistribution.earned(usd1.address, user1.address)).to.equal(toWei("6"));
    expect(await rewardDistribution.earned(usd1.address, user2.address)).to.equal(toWei("4"));

    await rewardDistribution.connect(user1).getAllRewards();
    await tm.skipBlock(1);
    expect(await rewardDistribution.earned(usd1.address, user1.address)).to.equal(toWei("1"));
    expect(await rewardDistribution.earned(usd1.address, user2.address)).to.equal(toWei("5"));
  });
});

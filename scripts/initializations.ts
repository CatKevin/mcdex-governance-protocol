const hre = require("hardhat");
const ethers = hre.ethers;

import { DeploymentOptions } from "./deployer/deployer";
import { readOnlyEnviron } from "./deployer/environ";
import { sleep, ensureFinished, printInfo, printError } from "./deployer/utils";

export function toWei(n) {
  return ethers.utils.parseEther(n);
}
export function fromWei(n) {
  return ethers.utils.formatEther(n);
}

const ENV: DeploymentOptions = {
  network: hre.network.name,
  artifactDirectory: "./artifacts/contracts",
  addressOverride: {},
};

const blockTime = async () => {
  return (await ethers.provider.getBlock()).timestamp;
};

const blockNumber = async () => {
  return (await ethers.provider.getBlock()).number;
};

const waitForBlockTime = async (duration) => {
  const start = await blockTime();
  while (true) {
    const elapsed = (await blockTime()) - start;
    if (elapsed > duration) {
      return;
    }
    await sleep(5000);
  }
};

export async function startMining(deployer, accounts) {
  const xmcb = await deployer.getDeployedContract("XMCB");
  const authenticator = await deployer.getDeployedContract("Authenticator");
  const rewardDistribution = await deployer.getDeployedContract("RewardDistribution");

  await ensureFinished(rewardDistribution.initialize(authenticator.address, xmcb.address));
  await ensureFinished(xmcb.addComponent(rewardDistribution.address));
  await ensureFinished(rewardDistribution.createRewardPlan(deployer.addressOf("MCB"), toWei("0.2")));
  await ensureFinished(rewardDistribution.notifyRewardAmount(deployer.addressOf("MCB"), toWei("20000")));
  printInfo("mining started");
}

export async function initialize(deployer, accounts) {
  const developer = accounts[0];
  const admin = accounts[0];

  const mcb = await deployer.getDeployedContract("MCB");
  const authenticator = await deployer.getDeployedContract("Authenticator");
  const xmcb = await deployer.getDeployedContract("XMCB");
  const vault = await deployer.getDeployedContract("Vault");
  const valueCapture = await deployer.getDeployedContract("ValueCapture");
  const mcbMinter = await deployer.getDeployedContract("MCBMinter");
  const timelock = await deployer.getDeployedContract("Timelock");
  const governor = await deployer.getDeployedContract("FastGovernorAlpha");
  const rewardDistribution = await deployer.getDeployedContract("rewardDistribution");

  await ensureFinished(authenticator.initialize());
  printInfo("authenticator initialization done");

  await ensureFinished(xmcb.initialize(authenticator.address, mcb.address, toWei("0.05")));
  printInfo("xmcb initialization done");

  await ensureFinished(vault.initialize(authenticator.address));
  printInfo("vault initialization done");

  await ensureFinished(valueCapture.initialize(authenticator.address, vault.address));
  printInfo("valueCapture initialization done");

  await ensureFinished(rewardDistribution.initialize(authenticator.address, xmcb.address));
  printInfo("rewardDistribution initialization done");

  await ensureFinished(
    mcbMinter.initialize(
      authenticator.address,
      mcb.address,
      developer.address,
      8506173,
      "1100001000000000000000000", // 1100001000000000000000000 L1 + L2
      toWei("0.2")
    )
  );

  // const bn = await blockNumber()
  await ensureFinished(
    mcbMinter.newRound(deployer.addressOf("MCBVesting"), toWei("700000"), toWei("0.55392"), 8812559)
  );
  printInfo("mcbMinter initialization done");

  await ensureFinished(
    timelock.initialize(
      governor.address,
      300 // 300s for test
    )
  );
  await ensureFinished(governor.initialize(mcb.address, timelock.address, xmcb.address, admin.address, 23));

  // roles
  const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";
  await ensureFinished(authenticator.grantRole(DEFAULT_ADMIN_ROLE, timelock.address));
  printInfo("timelock && governor initialization done");
  await ensureFinished(authenticator.grantRole(ethers.utils.id("VALUE_CAPTURE_ROLE"), valueCapture.address));
  printInfo("MCB MINTER_ROLE initialization done");
  //   await ensureFinished(authenticator.grantRole(ethers.utils.id("MINTER_ROLE"), timelock.address));
  //   printInfo("MCB MINTER_ROLE initialization done");
}

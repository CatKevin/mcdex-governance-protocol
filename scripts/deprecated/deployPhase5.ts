const hre = require("hardhat")
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo, printError } from './deployer/utils'

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {}
}

async function main(deployer, accounts) {
    const owner = accounts[0]
    const authenticator = await deployer.getDeployedContract("Authenticator")
    const xmcb = await deployer.getDeployedContract("XMCB")

    // vault
    printInfo("creating Vault ...")
    const vault = await deployer.deploy("Vault");
    await ensureFinished(vault.initialize(authenticator.address));
    printInfo("done")

    // value capture
    printInfo("creating Vault Capture ...")
    const valueCapture = await deployer.deploy("ValueCapture");
    await ensureFinished(valueCapture.initialize(authenticator.address, deployer.addressOf("DataExchange"), vault.address));
    await ensureFinished(authenticator.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", deployer.addressOf("Timelock")));
    printInfo("done")

    // test in & out
    printInfo("creating Test Token Seller ...")
    const tokenIn1 = await deployer.deployAs("CustomERC20", "TKN1", "TKN1", "TKN1", 18);
    const tokenOu1 = await deployer.deployAs("CustomERC20", "USD1", "USD1", "USD1", 18);

    // a mock convertor
    const seller1 = await deployer.deploy("ConstantSeller", tokenIn1.address, tokenOu1.address, toWei("4"))
    const oracle = await deployer.deploy("MockTWAPOracle");
    await ensureFinished(oracle.setPrice(toWei("5")))

    await ensureFinished(valueCapture.addUSDToken(tokenOu1.address, 18))
    await ensureFinished(valueCapture.setConvertor(tokenIn1.address, oracle.address, seller1.address, toWei("0.01")))
    printInfo("done")

    // reward distrubution && start mining
    printInfo("creating Reward Distribution ...")
    const rewardDistrubution = await deployer.deploy("TestRewardDistribution", authenticator.address, xmcb.address);
    await ensureFinished(xmcb.addComponent(rewardDistrubution.address));
    await ensureFinished(rewardDistrubution.createRewardPlan(deployer.addressOf("MCB"), toWei("0.2")))
    await ensureFinished(rewardDistrubution.notifyRewardAmount(deployer.addressOf("MCB"), toWei("20000")))
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
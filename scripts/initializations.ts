const hre = require("hardhat");
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { readOnlyEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo, printError } from './deployer/utils'

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
    }
}

const blockTime = async () => {
    return (await ethers.provider.getBlock()).timestamp
}

const blockNumber = async () => {
    return (await ethers.provider.getBlock()).number
}

const waitForBlockTime = async (duration) => {
    const start = await blockTime()
    while (true) {
        const elapsed = (await blockTime()) - start;
        if (elapsed > duration) {
            return
        }
        await sleep(5000)
    }
}

export async function startMining(deployer, accounts) {

    const xmcb = await deployer.getDeployedContract("XMCB")
    const authenticator = await deployer.getDeployedContract("Authenticator")
    const rewardDistrubution = await deployer.getDeployedContract("RewardDistribution")


    await ensureFinished(rewardDistrubution.initialize(authenticator.address, xmcb.address));
    await ensureFinished(xmcb.addComponent(rewardDistrubution.address));
    await ensureFinished(rewardDistrubution.createRewardPlan(deployer.addressOf("MCB"), toWei("0.2")))
    await ensureFinished(rewardDistrubution.notifyRewardAmount(deployer.addressOf("MCB"), toWei("20000")))
    printInfo("mining started")
}

export async function initialize(deployer, accounts) {

    const developer = accounts[0]
    const admin = accounts[0]
    const seriesAVesting = "0x6766F3CFD606E1E428747D3364baE65B6f914D56"


    const mcb = await deployer.getDeployedContract("MCB")
    const authenticator = await deployer.getDeployedContract("Authenticator")
    const xmcb = await deployer.getDeployedContract("XMCB")
    const vault = await deployer.getDeployedContract("Vault")
    const valueCapture = await deployer.getDeployedContract("ValueCapture")
    const mcbMinter = await deployer.getDeployedContract("MCBMinter")
    const timelock = await deployer.getDeployedContract("Timelock")
    const governor = await deployer.getDeployedContract("FastGovernorAlpha")

    await ensureFinished(authenticator.initialize());
    printInfo("authenticator initialzation done")

    await ensureFinished(xmcb.initialize(
        authenticator.address,
        mcb.address,
        toWei("0.05"),
    ));
    printInfo("xmcb initialzation done")

    await ensureFinished(vault.initialize(
        authenticator.address,
    ));
    printInfo("vault initialzation done")

    await ensureFinished(valueCapture.initialize(
        authenticator.address,
        vault.address,
    ));
    printInfo("valueCapture initialzation done")

    await ensureFinished(mcbMinter.initialize(
        authenticator.address,
        mcb.address,
        developer.address,
        1000,
        0,
        toWei("0.2"),
    ));

    const bn = await blockNumber()
    await ensureFinished(mcbMinter.newRound(
        seriesAVesting,
        toWei("700000"),
        toWei("0.55392"),
        bn + 10,
    ));
    printInfo("mcbMinter initialzation done")

    await ensureFinished(timelock.initialize(
        governor.address,
        300 // 300s for test
    ));
    await ensureFinished(governor.initialize(
        mcb.address,
        timelock.address,
        xmcb.address,
        admin.address,
        23
    ));
    await ensureFinished(
        authenticator.grantRole(
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            timelock.address
        ));
    printInfo("timelock && governor initialzation done")

}



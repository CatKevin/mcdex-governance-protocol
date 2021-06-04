
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
    addressOverride: {

    }
}

// onL1
async function main(deployer, accounts) {
    const owner = accounts[0]

    const timelock = await deployer.getDeployedContract("Timelock")
    const governor = await deployer.getDeployedContract("FastGovernorAlpha")

    // set admin to governor && restore delay
    const eta = (await ethers.provider.getBlock()).timestamp + 20; // arb5
    // const eta = Math.floor(Date.now() / 1000)  // s10
    await ensureFinished(timelock.queueTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    ))
    await ensureFinished(timelock.queueTransaction(
        timelock.address,
        0,
        "setDelay(uint256)",
        ethers.utils.defaultAbiCoder.encode(["uint256"], [300]),
        eta
    ))
    await sleep(20000)
    await ensureFinished(timelock.executeTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    ))
    await ensureFinished(timelock.executeTransaction(
        timelock.address,
        0,
        "setDelay(uint256)",
        ethers.utils.defaultAbiCoder.encode(["uint256"], [300]),
        eta
    ))

    await ensureFinished(governor.__acceptAdmin())
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
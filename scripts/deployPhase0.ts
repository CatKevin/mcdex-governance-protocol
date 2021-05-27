const hre = require("hardhat");
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

async function main(deployer, accounts) {
    // authenticator
    printInfo("creating Authenticator ...")
    const authenticator = await deployer.deploy("Authenticator")
    await ensureFinished(authenticator.initialize());
    printInfo("done")

    // fake mcb
    // const l1Provider = new ethers.providers.JsonRpcProvider(hre.network.config.urlL1)
    // const l1Wallet = new ethers.Wallet(hre.network.config.accounts[0], l1Provider)
    // printInfo("creating Test MCB ...")
    // await deployer.deployWith(l1Wallet, "MCB", "fakeMCB", "fakeMCB", 18);
    // printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });



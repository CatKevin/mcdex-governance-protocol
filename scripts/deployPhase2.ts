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
        L2MCB: "0xb2A0C50ebD8e8185D9dd8F3e361904119EAb8573" // l2
    }
}

async function main(deployer, accounts) {
    // xmcb
    printInfo("creating XMCB ...")
    const xmcb = await deployer.deploy("XMCB");
    await ensureFinished(xmcb.initialize(
        deployer.addressOf("Authenticator"),
        deployer.addressOf("L2MCB"),
        toWei("0.05")
    ))
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
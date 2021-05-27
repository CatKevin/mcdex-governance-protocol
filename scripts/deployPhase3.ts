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
    // timelock & governor
    printInfo("creating Voting System ...")
    console.log(owner.address)
    const timelock = await deployer.deploy("Timelock", owner.address, 0);
    const governor = await deployer.deploy(
        "FastGovernorAlpha",
        deployer.addressOf("DataExchange"),
        deployer.addressOf("Timelock"),
        deployer.addressOf("XMCB"),
        owner.address,
        22
    );
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
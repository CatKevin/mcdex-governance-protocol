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

async function vault(deployer, accounts) {
    // prepare
    const ftk = await deployer.deploy("FTK", "FToken", "FToken", 18)

    //
    const valueCapture = await deployer.getDeployedContract("ValueCapture")
    await ftk.mint(valueCapture.address, toWei("10000"))


}


async function main(deployer, accounts) {
    await vault(deployer, accounts)
}

ethers.getSigners()
    .then(accounts => readOnlyEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });



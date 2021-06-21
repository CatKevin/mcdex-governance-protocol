
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

    printInfo("creating Minter ...")
    const mintInitiator = await deployer.deploy("MockMintInitiator")
    const mcb = await deployer.getDeployedContract("MCB")
    const minter = await deployer.deploy(
        "MockMinter",
        deployer.addressOf("MockMintInitiator"),
        deployer.addressOf("MCB"),
        deployer.addressOf("MockDataExchange"),
        owner.address,
        owner.address,
        toWei("4000000"),
        toWei("4000000"),
        toWei("0.2"),
        toWei("0.55392"),
        0,
    )
    await mintInitiator.initialize(deployer.addressOf("Authenticator"), deployer.addressOf("MockMinter"))
    await mcb.grantRole(ethers.utils.id("MINTER_ROLE"), minter.address);

    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
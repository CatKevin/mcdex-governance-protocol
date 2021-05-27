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
        L1MCB: "0x553ac3a5bee98ac727a823153fa67c2d119d221b", // L1
    }
}

// onL1
async function main(deployer, accounts) {

    const mintInitiator = await deployer.deploy("MintInitiator")

    const l1Provider = new ethers.providers.JsonRpcProvider(hre.network.config.urlL1)
    const l1Wallet = new ethers.Wallet(hre.network.config.accounts[0], l1Provider)

    const owner = accounts[0]
    printInfo("creating Minter ...")
    await deployer.deployWith(
        l1Wallet,
        "Minter",
        deployer.addressOf("MintInitiator"),
        deployer.addressOf("L1MCB"),
        deployer.addressOf("DataExchange"),
        owner.address,
        owner.address,
        toWei("4000000"),
        toWei("4000000"),
        toWei("0.2"),
        toWei("0.55392"),
    )
    await mintInitiator.initialize(deployer.addressOf("Authenticator"), deployer.addressOf("Minter"))
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
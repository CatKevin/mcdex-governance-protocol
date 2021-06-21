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
    let MCB_TOTAL_SUPPLY_KEY = ethers.utils.id("MCB_TOTAL_SUPPLY_KEY")
    let TOTAL_CAPTURED_USD_KEY = ethers.utils.id("TOTAL_CAPTURED_USD_KEY")

    console.log("MCB_TOTAL_SUPPLY_KEY", MCB_TOTAL_SUPPLY_KEY)
    console.log("TOTAL_CAPTURED_USD_KEY", TOTAL_CAPTURED_USD_KEY)

    const dataExchange = await deployer.getDeployedContract("DataExchange")

    await dataExchange.updateDataSource(
        MCB_TOTAL_SUPPLY_KEY,
        deployer.addressOf("Minter")
    )
    await dataExchange.updateDataSource(
        TOTAL_CAPTURED_USD_KEY,
        deployer.addressOf("ValueCapture")
    )
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
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
        WETH9: "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
    }
}

async function deployDataExchange(deployer, authenticator, accounts) {
    const l1Provider = new ethers.providers.JsonRpcProvider(hre.network.config.urlL1)
    const l2Provider = new ethers.providers.JsonRpcProvider(hre.network.config.url)

    let privateKey = ethers.utils.randomBytes(32)
    printInfo(`generate new account with ${ethers.utils.hexlify(privateKey)} `)
    let src = {
        l1: new ethers.Wallet(hre.network.config.accounts[0], l1Provider),
        l2: new ethers.Wallet(hre.network.config.accounts[0], l2Provider),
    }
    let dst = {
        l1: new ethers.Wallet(privateKey, l1Provider),
        l2: new ethers.Wallet(privateKey, l2Provider),
    }
    // send deployment funds
    await ensureFinished(src.l1.sendTransaction({
        to: dst.l1.address,
        value: toWei("0.1"),
        gasLimit: 25000,
    }))

    await ensureFinished(src.l2.sendTransaction({
        to: dst.l2.address,
        value: toWei("0.1"),
        gasLimit: 825000,
    }))

    let l1Deployed
    let l2Deployed
    try {
        l1Deployed = await deployer.deployWith(dst.l1, "DataExchange")
        l2Deployed = await deployer.deployWith(dst.l2, "DataExchange")
        await ensureFinished(l1Deployed.initialize(authenticator))
        await ensureFinished(l2Deployed.initialize(authenticator))
        return { l1DataExchange: l1Deployed, l2DataExchange: l2Deployed }
    } catch (err) {
        printError(err)
        throw err
    }
}

async function main(deployer, accounts) {
    // data exchange
    printInfo("creating DataExchange ...")
    const { l1DataExchange, l2DataExchange } = await deployDataExchange(
        deployer,
        deployer.addressOf("Authenticator"),
        accounts,
    );
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });



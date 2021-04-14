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

async function deployDataExchange(deployer, authenticator) {
    const l1Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:7545")
    const l2Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:8547")


    let privateKey = ethers.utils.randomBytes(32)
    let l1Wallet = new ethers.Wallet(privateKey, l1Provider)
    let l2Wallet = new ethers.Wallet(privateKey, l2Provider)
    let l1Owner = new ethers.Wallet(hre.network.config.accounts[0], l1Provider)

    // send deployment funds
    const ownerWallet = hre.ethers.provider.getSigner(0);
    const feeTx = await ensureFinished(l1Owner.sendTransaction({
        to: l1Wallet.address,
        value: toWei("0.1"),
        gasLimit: 25000,
    }))

    let l1Deployed
    let l2Deployed
    try {
        l1Deployed = await deployer.deployWith(l1Wallet, "DataExchange")
        l2Deployed = await deployer.deployWith(l2Wallet, "DataExchange")
        await ensureFinished(l1Deployed.initialize(authenticator.address))
        await ensureFinished(l2Deployed.initialize(authenticator.address))
        return { l1DataExchange: l1Deployed, l2DataExchange: l2Deployed }
    } catch (err) {
        printError(err)
        throw err
    } finally {
        // refund deployment funds
        let refund = await l1Wallet.getBalance()
        printInfo(`${refund} left`)
        const transferCost = ethers.BigNumber.from(feeTx.gasPrice).mul(ethers.BigNumber.from(25000))
        // printInfo(`${transferCost} for transfer fee`)
        if (refund.gt(transferCost)) {
            refund = refund.sub(transferCost)
            printInfo(`refund ${refund} to ${await ownerWallet.getAddress()}`);
            await l1Wallet.sendTransaction({
                to: await ownerWallet.getAddress(),
                value: refund,
                gasLimit: 25000,
                gasPrice: feeTx.gasPrice,
            })

        }
    }
}

async function main(deployer, accounts) {
    const owner = accounts[0]
    const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000"
    const TEST_DATA_KEY = ethers.utils.id("TEST_DATA_KEY")
    // authenticator
    printInfo("creating Authenticator ...")
    const authenticator = await deployer.deploy("Authenticator")
    await ensureFinished(authenticator.initialize());
    printInfo("done")

    // data exchange
    printInfo("creating DataExchange ...")
    const { l1DataExchange, l2DataExchange } = await deployDataExchange(deployer, authenticator);
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });



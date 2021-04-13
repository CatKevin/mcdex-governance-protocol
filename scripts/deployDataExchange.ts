const hre = require("hardhat");
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { sleep } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        WETH9: "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
    }
}

async function main(deployer, ...args) {
    const l1Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:7545")
    const l2Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:8547")
    const refundRecipient = '0x02e8735cd053fc738170011F7eBc4117f285fE9D'

    let privateKey = ethers.utils.randomBytes(32)
    let l1Wallet = new ethers.Wallet(privateKey, l1Provider)
    let l2Wallet = new ethers.Wallet(privateKey, l2Provider)

    let isReady = false
    console.log("checking nonce...")
    while (!isReady) {
        const l1TxCount = await l1Wallet.getTransactionCount();
        const l2TxCount = await l1Wallet.getTransactionCount();
        if (l1TxCount == 0 && l2TxCount == 0) {
            isReady = true
        } else {
            privateKey = ethers.utils.randomBytes(32)
            l1Wallet = new ethers.Wallet(privateKey, l1Provider)
            l2Wallet = new ethers.Wallet(privateKey, l2Provider)
        }
    }
    console.log(`done. temp private key is ${ethers.utils.hexlify(privateKey)}`)

    isReady = false
    console.log(`please transfer some ether to ${l1Wallet.address} to begin deployment...`);
    while (!isReady) {
        const fund = await l1Wallet.getBalance();
        isReady = fund > 0
        await sleep(3000)
        process.stdout.write(".")
    }
    console.log(`done`);

    try {
        const l1Deployed = await deployer.deployWith(l1Wallet, "DataExchange")
        const l2Deployed = await deployer.deployWith(l2Wallet, "DataExchange")
    } catch (err) {
        console.log("deployment interrupted, rolling back (refund):", err)
    }

    let refund = await l1Wallet.getBalance()
    console.log(`${refund} left to refund`)

    const gasPrice = hre.network.config.gasPrice
    const transferCost = ethers.BigNumber.from(gasPrice).mul(ethers.BigNumber.from(23000))
    console.log(`${transferCost} left to refund`)

    if (refund.gt(transferCost)) {
        refund = refund.sub(transferCost)
        console.log(`refund ${refund} to ${refundRecipient}`);
        await l1Wallet.sendTransaction({
            to: refundRecipient,
            value: refund,
            gasLimit: 23000,
        })
        console.log(`done`);
    }
    return
}

export async function deployDataExchange() {
    return await restorableEnviron(ENV, main)
}

restorableEnviron(ENV, main).then(console.log)



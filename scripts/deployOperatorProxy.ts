const hre = require("hardhat");
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
    }
}

import { deploy } from "./deployments"
import { initialize, startMining } from "./initializations"

async function main(deployer, accounts) {
    await deployer.deployAsUpgradeable("OperatorProxy", "0x02e8735cd053fc738170011F7eBc4117f285fE9D")

    const proxy = await deployer.getDeployedContract("OperatorProxy")
    await proxy.initialize()
    await proxy.addMaintainer("0x02e8735cd053fc738170011F7eBc4117f285fE9D");
    // await proxy.addMaintainer();
}

async function mainOnline(deployer, accounts) {


    // 0x25c 执行
    // const authenticator = await deployer.getDeployedContract("Authenticator")
    // await authenticator.grantRole(ethers.utils.id("OPERATOR_ADMIN_ROLE"), "address can do any operator options")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
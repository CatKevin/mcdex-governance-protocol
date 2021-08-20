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
    await deployer.deploy("ProxyAdmin")
    const PROXY_ADMIN_ROLE = ethers.utils.id("DAO_OWNED_POOL_OPERATOR_ROLE")

    await deployer.deployAsUpgradeable("Authenticator", deployer.addressOf("ProxyAdmin"))
    await deployer.deployAsUpgradeable("ExecutionProxy", deployer.addressOf("ProxyAdmin"))

    const authenticator = await deployer.getDeployedContract("Authenticator")
    await authenticator.initialize()
    const proxy = await deployer.getDeployedContract("ExecutionProxy")
    await proxy.initialize(authenticator.address, PROXY_ADMIN_ROLE)
    await authenticator.grantRole(PROXY_ADMIN_ROLE, "0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a")
}

async function mainOnline(deployer, accounts) {
    const proxy = await deployer.deployAsUpgradeable("OperatorProxy", deployer.addressOf("ProxyAdmin"))
    await proxy.initialize(deployer.addressOf("Authenticator"))

    const OPERATOR_ADMIN_ROLE = ethers.utils.id("OPERATOR_ADMIN_ROLE")
    const OPERATOR_ROLE = ethers.utils.id("OPERATOR_ROLE")

    const authenticator = await deployer.getDeployedContract("Authenticator")
    await authenticator.grantRole(OPERATOR_ADMIN_ROLE, "address can do any operator options")
    await authenticator.grantRole(OPERATOR_ROLE, "address can only check in")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
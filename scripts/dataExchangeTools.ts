const chalk = require('chalk')

import { Deployer } from './deployer/deployer'
import { DeploymentOptions } from './deployer/deployer'
import { readOnlyEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: "",
    artifactDirectory: './artifacts/contracts',
    addressOverride: {}
}

export async function checkAuth(hre, role, account) {
    ENV.network = hre.network.name
    const ethers = hre.ethers
    await readOnlyEnviron(ethers, ENV, async deployer => {
        const authenticator = await deployer.getDeployedContract("Authenticator")
        printInfo(await authenticator.hasRole(role, account))
    })
}

export async function updateDataSource(hre, key, account) {
    ENV.network = hre.network.name
    const ethers = hre.ethers
    await readOnlyEnviron(ethers, ENV, async deployer => {
        const dataExchange = await deployer.getDeployedContract("DataExchange")
        await ensureFinished(dataExchange.updateDataSource(key, account, { gasLimit: 1000000 }))
        printInfo("all set")
    })
}
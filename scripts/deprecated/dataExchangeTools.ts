const chalk = require('chalk')

import { Deployer } from '../deployer/deployer'
import { DeploymentOptions } from '../deployer/deployer'
import { readOnlyEnviron } from '../deployer/environ'
import { sleep, ensureFinished, printInfo } from '../deployer/utils'

const ROLLUP_ADDRESS = "0x19914a2873136aE17E25E4eff6088BF17f3ea3a3"

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

export async function pushToL2(hre, key, value) {
    ENV.network = hre.network.name
    const ethers = hre.ethers
    await readOnlyEnviron(ethers, ENV, async deployer => {


        // const l1Provider = new ethers.providers.JsonRpcProvider(hre.network.l1URL)
        // var iface = new ethers.utils.Interface([
        //     "function bridge()",
        //     "function allowedInboxList(uint256 index) external view returns (address)"
        // ])
        // var calldata = iface.encodeFunctionData("bridge")
        // const result = await l1Provider.call({ to: ROLLUP_ADDRESS, data: calldata, })
        // const bridge = "0x" + result.slice(26)




        // const dataExchange = await deployer.getDeployedContract("DataExchange")
        // await dataExchange.feedDataFromL1(
        //     key,
        //     value,

        // )
        // printInfo("done")
    })
}

export async function pushToL1(hre, key, value) {
    ENV.network = hre.network.name
    const ethers = hre.ethers
    await readOnlyEnviron(ethers, ENV, async deployer => {

        printInfo(key, value)

        const dataExchange = await deployer.getDeployedContract("DataExchange")
        await dataExchange.feedDataFromL2(key, value)
        printInfo("done")
    })
}


export async function showDetails(hre) {
    ENV.network = hre.network.name
    const ethers = hre.ethers
    await readOnlyEnviron(ethers, ENV, async deployer => {
        const dataExchange = await deployer.getDeployedContract("DataExchange")
        const filter = dataExchange.filters.UpdateDataSource(null, null)
        const events = await dataExchange.queryFilter(filter)
        console.log(events)
        printInfo("done")
    })
}
const hre = require("hardhat");
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        // arb-rinkeby
        "MCB": "0xE495e9bC15cBAD2E2E957D278749Fb07B8a98fDe",
        "MCBVesting": "0x49FCebBc49Fc617b901E4086dEfB8Cc016a4BD17",
        "ProxyAdmin": "0xA712f0D80Fc1066a73649D004e3E0D92150ae1f6",
    }
}

import { deploy } from "./deployments"
import { initialize, startMining } from "./initializations"

async function main(deployer, accounts) {

    await deployer.deployOrSkip("MCB", "fakeMCB", "fakeMCB", 18);

    await deploy(deployer, accounts);
    await initialize(deployer, accounts);
    // await startMining(deployer, accounts)
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
const hre = require("hardhat");
import { Deployer } from './deployer'

export async function restorableEnviron(options, job, ...args) {
    // detect network
    const deployer = new Deployer(options)
    await deployer.initialize();
    // main logic
    try {
        await job(deployer, ...args)
    } catch (err) {
        console.log("Error occurs when deploying contracts:", err)
    }
    // save deployed
    deployer.finalize()
}

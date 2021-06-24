const hre = require("hardhat");
const chalk = require('chalk')
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { readOnlyEnviron } from './deployer/environ'
import { printError } from './deployer/utils'

function passOrWarn(title, cond) {
    return cond ? chalk.greenBright(title) : chalk.red(title)
}

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {}
}

async function verifyRoles(deployer, accounts) {

    const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"

    const fetchRoleAccounts = async (contract, granted, roleName, roleValue) => {
        console.log(" ", roleName, `[ ${roleValue} ]`)
        const roleCount = (await contract.getRoleMemberCount(roleValue)).toNumber()
        granted[roleName] = []
        for (var j = 0; j < roleCount; j++) {
            const account = await contract.getRoleMember(roleValue, j)
            console.log(`  - ${account}`)
            granted[roleName].push(account)
        }
    }

    // authenticator
    const authenticator = await deployer.getDeployedContract("Authenticator")
    const granted = {}

    console.log("Authenticator Granted:")
    console.log("========================")
    const authenticatorRoles = [
        "VALUE_CAPTURE_ADMIN_ROLE",
        "XMCB_ADMIN_ROLE",
        "MINTER_ADMIN_ROLE",
        "VALUE_CAPTURE_ROLE"
    ]
    // admin
    await fetchRoleAccounts(authenticator, granted, "DEFAULT_ADMIN_ROLE", adminRole)
    // sub-roles
    for (var i = 0; i < authenticatorRoles.length; i++) {
        const roleName = authenticatorRoles[i];
        const roleValue = ethers.utils.id(roleName)
        await fetchRoleAccounts(authenticator, granted, roleName, roleValue)
    }

    const mcb = await deployer.getDeployedContract("MCB")
    const mcbGranted = {}
    const mcbRoles = [
        "MINTER_ROLE",
    ]
    console.log("MCB Granted:")
    console.log("========================")
    // admin
    await fetchRoleAccounts(mcb, mcbGranted, "DEFAULT_ADMIN_ROLE", adminRole)
    // sub-roles
    for (var i = 0; i < mcbRoles.length; i++) {
        const roleName = mcbRoles[i];
        const roleValue = ethers.utils.id(roleName)
        await fetchRoleAccounts(mcb, mcbGranted, roleName, roleValue)
    }

    const valueCapture = await deployer.getDeployedContract("ValueCapture")
    const captureNotifyRecipient = await valueCapture.captureNotifyRecipient();

    console.log("Checklist:")
    console.log("========================")
    console.log("  -", passOrWarn("Authenticator.VALUE_CAPTURE_ROLE: <= 1", granted["VALUE_CAPTURE_ROLE"].length <= 1))
    console.log("  -", passOrWarn("Authenticator.VALUE_CAPTURE_ROLE: has ValueCapture", granted["VALUE_CAPTURE_ROLE"].includes(deployer.addressOf("ValueCapture"))))

    console.log("  -", passOrWarn("Authenticator.DEFAULT_ADMIN_ROLE: <= 1", granted["DEFAULT_ADMIN_ROLE"].length <= 1))
    console.log("  -", passOrWarn("Authenticator.DEFAULT_ADMIN_ROLE: has ValueCapture", granted["DEFAULT_ADMIN_ROLE"].includes(deployer.addressOf("Timelock"))))

    console.log("  -", passOrWarn("Authenticator.VALUE_CAPTURE_ADMIN_ROLE: <= 1", granted["VALUE_CAPTURE_ADMIN_ROLE"].length <= 1))
    console.log("  -", passOrWarn("Authenticator.XMCB_ADMIN_ROLE: <= 1", granted["XMCB_ADMIN_ROLE"].length <= 1))
    console.log("  -", passOrWarn("Authenticator.MINTER_ADMIN_ROLE: <= 1", granted["MINTER_ADMIN_ROLE"].length <= 1))

    console.log("  -", passOrWarn("MCB.DEFAULT_ADMIN_ROLE: <= 1", mcbGranted["DEFAULT_ADMIN_ROLE"].length <= 1))
    console.log("  -", passOrWarn("MCB.MINTER_ROLE: <= 1", mcbGranted["MINTER_ROLE"].length <= 1))
    console.log("  -", passOrWarn("MCB.MINTER_ROLE: has MCBMinter", mcbGranted["MINTER_ROLE"].includes(deployer.addressOf("MCBMinter"))))

    console.log("  -", passOrWarn("ValueCapture.captureNotifyRecipient: is MCBMinter", captureNotifyRecipient == deployer.addressOf("MCBMinter")))
}

async function main(deployer, accounts) {
    await verifyRoles(deployer, accounts)

}

ethers.getSigners()
    .then(accounts => readOnlyEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
const ethers = require("ethers")
import { Bridge } from 'arb-ts'
import { S10 as ENV } from './env'
import {
    toWei,
    printInfo,
    printError
} from './utils'

const RECIPIENT = process.argv[process.argv.length - 1]
const L1_RPC_CALLER_PRIVATE_KEY = process.env["DEPOSIT_PRIVATE_KEY"]

async function main() {
    const ethProvider = new ethers.providers.JsonRpcProvider(ENV.L1_RPC_ENDPOINT)
    const arbProvider = new ethers.providers.JsonRpcProvider(ENV.L2_RPC_ENDPOINT)

    const connectedL1Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, ethProvider)
    const connectedL2Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, arbProvider)

    const bridge = new Bridge(
        ENV.ERC20_BRIDGE_ADDRESS,
        ENV.ARB_ERC20_BRIDGE_ADDRESS,
        connectedL1Wallet,
        connectedL2Wallet
    )
    await bridge.depositETH(
        toWei("10"),
        RECIPIENT,
        ethers.BigNumber.from(0),
        ethers.BigNumber.from(0),
    )
    printInfo(`depositETH to ${RECIPIENT}`)
}

main().then().catch(printError)
const ethers = require("ethers")
import { Bridge } from 'arb-ts'
import { KOVAN as ENV } from './env'
import {
    toWei,
    sleep,
    printInfo,
    printError
} from './utils'

const TRANSACTION_RECIPIENT = "0x5D155F969F5E6DB3FEeaA103853f42907B44f474"
const L1_RPC_CALLER_PRIVATE_KEY = process.env["CROSS_KEEPER_PRIVATE_KEY"]
const MAX_RETRY = 1

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

    let events = (await bridge.getL2ToL1EventData(TRANSACTION_RECIPIENT))
        .map(x => { { return { bn: x.batchNumber, ib: x.indexInBatch } } })
    printInfo(`found ${events.length} transactions`)

    for (let i = 0; i < events.length; i++) {
        const e = events[i]
        printInfo(`executing batchNumber=${e.bn.toString()} index=${e.ib.toString()}`)
        try {
            const tryExecute = async (e) => {
                let retry = 1
                do {
                    try {
                        await bridge.triggerL2ToL1Transaction(e.bn, e.ib)
                        break
                    } catch (error) {
                        retry++
                        if (retry <= MAX_RETRY) {
                            printError(`wait for ${retry} retry`)
                            await sleep(3000)
                        } else {
                            throw error
                        }
                    }
                } while (true)
            }
            await tryExecute(e)
            printInfo(`executing batchNumber=${e.bn.toString()} index=${e.ib.toString()} done`)
        } catch (error) {
            printError(`executing batchNumber=${e.bn.toString()} index=${e.ib.toString()} failed: [${error.code}] ${error.reason}`)
            // break
        }
    }
}

main().then().catch(printError)
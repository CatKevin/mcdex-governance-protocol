const ethers = require("ethers")
import { Bridge } from 'arb-ts'
import { RINKEBY as ENV } from './env'
import {
    toWei,
    sleep,
    printInfo,
    printError
} from './utils'

// const TRANSACTION_RECIPIENT = "0x01B019DCdfc39C537b1143c79a31B4733bD4C985"
const TRANSACTION_RECIPIENT = "0x917dc9a69F65dC3082D518192cd3725E1Fa96cA2"
const L1_RPC_CALLER_PRIVATE_KEY = process.env["CROSS_KEEPER_PRIVATE_KEY"]
const MAX_RETRY = 1

async function main() {
    const ethProvider = new ethers.providers.JsonRpcProvider(ENV.L1_RPC_ENDPOINT)
    const arbProvider = new ethers.providers.JsonRpcProvider(ENV.L2_RPC_ENDPOINT)

    const connectedL1Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, ethProvider)
    const connectedL2Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, arbProvider)

    const bridge = await Bridge.init(
        connectedL1Wallet,
        connectedL2Wallet,
        ENV.L1_GATEWAY_ROUTER,
        ENV.L2_GATEWAY_ROUTER,
    )

    let events = await bridge.getL2ToL1EventData(TRANSACTION_RECIPIENT)
    printInfo(`found ${events.length} transactions`)

    for (let i = 0; i < events.length; i++) {
        if (events[i].data.slice(2 + 8 + 24, 2 + 8 + 64) != "01b019dcdfc39c537b1143c79a31b4733bd4c985") {
            continue;
        }
        const e = { bn: events[i].batchNumber, ib: events[i].indexInBatch }
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
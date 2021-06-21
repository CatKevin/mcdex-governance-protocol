const ethers = require("ethers")
import { Bridge } from 'arb-ts'
import { RINKEBY as ENV } from './env'
import {
    toWei,
    sleep,
    printInfo,
    printError
} from './utils'

const TRANSACTION_RECIPIENT = "0x272fD185f10af2115BA2F82230fBb588B967aBCd"
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
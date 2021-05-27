const ethers = require("ethers")
const chalk = require('chalk')
import { ArbSys__factory } from './lib/abi/factories/ArbSys__factory'
import { Bridge } from './lib/bridge'

const ARB_SYS_ADDRESS = "0x0000000000000000000000000000000000000064"
const ROLLUP_ADDRESS = "0x2B0474e5201646fd7d8eEf8522a88376940B1db0"

const L1_RPC_ENDPOINT = "https://kovan.infura.io/v3/3582010d3cc14ab183653e5861d0c118"
const L2_RPC_ENDPOINT = "https://kovan5.arbitrum.io/rpc"
const TRANSACTION_RECIPIENT = "0x568D306946418C452452f4b9ee34d9d3b3eFF1AB"
const L1_RPC_CALLER_PRIVATE_KEY = "b49bdc31d49ece2ee667de5c0b378ce193af4153c554db624db71696911ac6c6"

function printInfo(...message) {
    console.log(chalk.yellow("INFO "), ...message)
}

function printError(...message) {
    console.log(chalk.red("ERRO "), ...message)
}

export function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function getBridge(l1Wallet, l2Wallet) {
    const l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC_ENDPOINT)
    var iface = new ethers.utils.Interface(["function delayedBridge()"])
    var calldata = iface.encodeFunctionData("delayedBridge")
    const result = await l1Provider.call({ to: ROLLUP_ADDRESS, data: calldata, })
    const bridgeAddress = "0x" + result.slice(26)
    return new Bridge("", bridgeAddress, l1Wallet, l2Wallet)
}

async function forwardL2Call(bridge, batchNumber, indexInBatch) {
    let retry = false
    do {
        try {
            printInfo(`try execute batchid = ${batchNumber}, indexinbatch = ${indexInBatch}`)
            await bridge.triggerL2ToL1Transaction(batchNumber, indexInBatch, true, false)
            printInfo(`done batchid = ${batchNumber}, indexinbatch = ${indexInBatch}`)
        } catch (err) {
            if (typeof err.error != 'undefined') {
                if (typeof err.error.body != 'undefined' && JSON.parse(err.error.body).error.message.includes("invalid opcode")) {
                    printError("retry")
                    retry = true
                    await sleep(30000)
                } else if (typeof err.error.error.body != 'undefined' && JSON.parse(err.error.error.body).error.message.includes("NO_OUTBOX")) {
                    printInfo(`skip batchid = ${batchNumber}, indexinbatch = ${indexInBatch}`)
                    retry = false
                } else {
                    printError(err)
                }
            }
        }
    } while (retry)
}

async function main() {
    const l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC_ENDPOINT)
    const l2Provider = new ethers.providers.JsonRpcProvider(L2_RPC_ENDPOINT)
    let l1Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, l1Provider)
    let l2Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, l2Provider)

    const bridge = await getBridge(l1Wallet, l2Wallet);
    console.log(`found bridge at ${bridge.address}`)

    const arbSys = ArbSys__factory.connect(ARB_SYS_ADDRESS, l2Provider)
    const filter = {
        address: ARB_SYS_ADDRESS,
        topics: [
            arbSys.interface.getEventTopic(
                arbSys.interface.getEvent('L2ToL1Transaction')
            ),
            ethers.utils.hexZeroPad(TRANSACTION_RECIPIENT, 32)
        ],
        fromBlock: 0,
        toBlock: 'latest',
    }

    console.log('scanning for txs ...')
    const logs = await l2Provider.getLogs(filter)

    for (let i = 0; i < logs.length; i++) {
        const entry = arbSys.interface.parseLog(logs[i]).args as any
        console.log(entry)
        let retry = false
        do {
            try {
                await forwardL2Call(bridge, entry.batchNumber, entry.indexInBatch)
                console.log(entry, "executed")
            } catch (err) {
                if (typeof err.error != 'undefined') {
                    if (typeof err.error.body != 'undefined' && JSON.parse(err.error.body).error.message.includes("invalid opcode")) {
                        printError("retry")
                        retry = true
                        await sleep(30000)
                    } else if (typeof err.error.error.body != 'undefined' && JSON.parse(err.error.error.body).error.message.includes("NO_OUTBOX")) {
                        printInfo(`skip batchid = ${entry.batchNumber}, indexinbatch = ${entry.indexInBatch}`)
                        retry = false
                    } else {
                        printError(err)
                    }
                }
            }
        } while (retry)
    }

    console.log(`listen on arb sys ...`)
    l2Provider.on(filter, async (log) => {
        const entry = arbSys.interface.parseLog(log).args as any
        await forwardL2Call(bridge, entry.batchNumber, entry.indexInBatch)
    })
}

main().then().catch(printError)
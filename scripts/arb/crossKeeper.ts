const ethers = require("ethers")
const chalk = require('chalk')
import { ArbSys__factory } from './lib/abi/factories/ArbSys__factory'
import { Bridge } from './lib/bridge'

const ARB_SYS_ADDRESS = "0x0000000000000000000000000000000000000064"
const ROLLUP_ADDRESS = "0x19914a2873136aE17E25E4eff6088BF17f3ea3a3"

const L1_RPC_ENDPOINT = "http://10.30.204.119:7545"
const L2_RPC_ENDPOINT = "http://10.30.204.119:8547"
const TRANSACTION_RECIPIENT = "0x0deF7be50883e3cB4d6c97d51933D1E44D10b12A"
const L1_RPC_CALLER_PRIVATE_KEY = "b49bdc31d49ece2ee667de5c0b378ce193af4153c554db624db71696911ac6c6"

function info(...message) {
    console.log(chalk.yellow("INFO "), ...message)
}

function error(...message) {
    console.log(chalk.red("ERRO "), ...message)
}

async function getBridge() {
    const l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC_ENDPOINT)
    var iface = new ethers.utils.Interface(["function bridge()"])
    var calldata = iface.encodeFunctionData("bridge")
    const result = await l1Provider.call({ to: ROLLUP_ADDRESS, data: calldata, })
    return "0x" + result.slice(26)
}

async function forwardL2Call(bridgeAddress, batchNumber, indexInBatch) {
    const l1Provider = new ethers.providers.JsonRpcProvider(L1_RPC_ENDPOINT)
    const l2Provider = new ethers.providers.JsonRpcProvider(L2_RPC_ENDPOINT)
    let l1Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, l1Provider)
    let l2Wallet = new ethers.Wallet(L1_RPC_CALLER_PRIVATE_KEY, l2Provider)

    const bridge = new Bridge("", bridgeAddress, l1Wallet, l2Wallet)
    await bridge.triggerL2ToL1Transaction(batchNumber, indexInBatch, true)
}

async function main() {

    const bridge = await getBridge();
    console.log(`found bridge at ${bridge}`)

    const l2Provider = new ethers.providers.JsonRpcProvider(L2_RPC_ENDPOINT)
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

    const logs = await l2Provider.getLogs(filter)
    logs.map(async log => {
        const entry = arbSys.interface.parseLog(log).args as any
        await forwardL2Call(bridge, entry.batchNumber, entry.indexInBatch)
    })

    console.log(`fetching l2tx ...`)
    l2Provider.on(filter, async (log) => {
        const entry = arbSys.interface.parseLog(log).args as any
        console.log(entry)
        await forwardL2Call(bridge, entry.batchNumber, entry.indexInBatch)
    })
}

main().then().catch(error)
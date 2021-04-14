import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
// import "hardhat-typechain";
import "./misc/typechain-ethers-v5-mcdex"
import "hardhat-contract-sizer";
// import "hardhat-gas-reporter";
// import "hardhat-abi-exporter";
import "solidity-coverage"

import { checkAuth, updateDataSource } from './scripts/dataExchangeTools'

task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task("encode", "Encode calldata")
    .addPositionalParam("sig", "Signature of function to call")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split(',')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        console.log("encoded calldata", calldata)
    })


task("deploy", "Deploy single contract")
    .addPositionalParam("name", "Name of contract to deploy")
    .addOptionalPositionalParam("args", "Args of contract constructor, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split(',')
        }
        const factory = await hre.ethers.getContractFactory(args.name);
        const contract = await factory.deploy(...args.args);
        console.log(args.name, "has been deployed to", contract.address);
    })

task("send", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split(',')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        // console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        // console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);

        const tx = await signer.sendTransaction({
            to: args.address,
            from: signer._address,
            data: calldata,
        });
        console.log(tx);
        console.log(await tx.wait());
    })

task("call", "Call contract function")
    .addPositionalParam("address", "Address of contract")
    .addPositionalParam("sig", "Signature of contract")
    .addOptionalPositionalParam("args", "Args of function call, seprated by common ','")
    .setAction(async (args, hre) => {
        if (typeof args.args != 'undefined') {
            args.args = args.args.split(',')
        }
        args.sig = args.sig.replace('function ', '')
        var iface = new hre.ethers.utils.Interface(["function " + args.sig])
        var selector = args.sig.slice(0, args.sig.indexOf('('))
        console.log(args.sig, args.args, selector)
        var calldata = iface.encodeFunctionData(selector, args.args)
        console.log("encoded calldata", calldata)
        const signer = hre.ethers.provider.getSigner(0);
        const result = await signer.call({
            to: args.address,
            data: calldata,
        })
        console.log(result);
    })


task("checkAuth", "CONTRACT_CALL")
    .addOptionalPositionalParam("key", "bytes32")
    .addOptionalPositionalParam("account", "address")
    .setAction(async (args, hre) => {
        if (!args.key.startsWith("0x")) {
            args.key = hre.ethers.utils.id(args.key)
        }
        await checkAuth(hre, args.key, args.account)
    })


task("updateDataSource", "CONTRACT_CALL")
    .addOptionalPositionalParam("key", "bytes32")
    .addOptionalPositionalParam("account", "address")
    .setAction(async (args, hre) => {
        await updateDataSource(hre, hre.ethers.utils.id(args.key), args.account)
    })

// task("updateDataSource", "CONTRACT_CALL")
//     .addOptionalPositionalParam("key", "bytes32")
//     .addOptionalPositionalParam("account", "address")
//     .setAction(async (args, hre) => {
//         await updateDataSource(hre, hre.ethers.utils.id(args.key), args.account)
//     })




module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            // loggingEnabled: true
        },
        tc: {
            url: "http://10.30.204.119:8547",
            gasPrice: 0,
            accounts: ["b49bdc31d49ece2ee667de5c0b378ce193af4153c554db624db71696911ac6c6"],
            timeout: 300000,
            confirmations: 10,
            l1URL: "http://10.30.204.119:7545",
        },
        arbtest: {
            url: "http://10.30.204.119:8547",
            gasPrice: 1e9,
            accounts: ["dc1dfb1ba0850f1e808eb53e4c83f6a340cc7545e044f0a0f88c0e38dd3fa40d"],
            timeout: 300000,
            confirmations: 10,
        },
        s10: {
            url: "http://server10.jy.mcarlo.com:8747",
            gasPrice: "auto",
            blockGasLimit: "8000000"
        },
        kovan: {
            url: "https://kovan.infura.io/v3/3582010d3cc14ab183653e5861d0c118",
            gasPrice: 1e9,
            accounts: ["0xd961926e05ae51949465139b95d91faf028de329278fa5db7462076dd4a245f4"],
            timeout: 300000,
            confirmations: 1,
        },
    },
    solidity: {
        version: "0.7.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: false,
        disambiguatePaths: false,
    },
    abiExporter: {
        path: './abi',
        clear: false,
        flat: true,
        only: ['PoolCreator', 'LiquidityPool'],
    },
    mocha: {
        timeout: 60000
    }
};

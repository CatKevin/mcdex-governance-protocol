const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from './utils';

async function main(accounts: any[]) {
    const user0 = accounts[0]
    const minter = await createContract("Minter", [
        "0xB030f46e4770c8418e7590DDf753226432b3D11d",
        "0xdFC1067cbCD2BF9a9f8511fD22B394bf5C70B4FB",
        user0.address,
        toWei("0.25"),
        toWei("10000000"),
        Math.floor(Date.now() / 1000),
        toWei("86400") // 1 persecond
    ]);

    console.table([
        ["minter", minter.address],
    ])
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
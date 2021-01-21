const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

async function main(accounts: any[]) {
    let stk;
    let rtk;
    let governor;
    let timelock;
    let admin = accounts[0];

    stk = await createContract("ShareToken");
    rtk = await createContract("CustomERC20", ["RTK", "RTK", 18]);
    timelock = await createContract("Timelock", [admin.address, 86400]);
    governor = await createContract("LPGovernor");

    await stk.initialize("STK", "STK", admin.address);
    await governor.initialize(stk.address, rtk.address, timelock.address, admin.address);

    console.table([
        ["STK", stk.address],
        ["RTK", rtk.address],
        ["Timelock", timelock.address],
        ["LPGovernor", governor.address],
    ])
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
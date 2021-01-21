const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

async function main(accounts: any[]) {
    let stk;
    let rtk;
    let governor;
    let timelock;
    let admin = accounts[0];

    // ┌─────────┬──────────────┬──────────────────────────────────────────────┐
    // │ (index) │      0       │                      1                       │
    // ├─────────┼──────────────┼──────────────────────────────────────────────┤
    // │    0    │    'STK'     │ '0xaDD8E8f1c70d362be2B6848861b2988789615582' │
    // │    1    │    'RTK'     │ '0xBAF9C6a3E6c0D66983ac26396133F4E7161a3c75' │
    // │    2    │  'Timelock'  │ '0x3d015e650FCBB8d68EB0a26d4d154D527c001f3B' │
    // │    3    │ 'LPGovernor' │ '0x609a7C544489b4976690Fc4a46332396085F1645' │
    // └─────────┴──────────────┴──────────────────────────────────────────────┘

    stk = await (await createFactory("ShareToken")).attach("0xaDD8E8f1c70d362be2B6848861b2988789615582");
    rtk = await (await createFactory("CustomERC20")).attach("0xBAF9C6a3E6c0D66983ac26396133F4E7161a3c75");
    governor = await (await createFactory("LPGovernor")).attach("0x609a7C544489b4976690Fc4a46332396085F1645");

    // await stk.mint(admin.address, toWei("1000"));
    // await stk.connect(admin).approve(governor.address, toWei("1000"));

    // await governor.connect(admin).stake(toWei("666"));
    await governor.connect(admin).withdraw(toWei("666"));
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
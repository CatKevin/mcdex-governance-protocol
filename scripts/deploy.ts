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
    // let target;
    let admin = accounts[0];

    // stk = await createContract("ShareToken");
    // rtk = await createContract("CustomERC20", ["RTK", "RTK", 18]);
    // governor = await createContract("TestLPGovernor");
    // // target = await createContract("MockLiquidityPool");

    // console.table([
    //     ["STK", stk.address],
    //     ["RTK", rtk.address],
    //     // ["Target", target.address],
    //     ["LPGovernor", governor.address],
    // ])

    // await stk.initialize("STK", "STK", admin.address);

    // zhichao
    // ┌─────────┬──────────────┬──────────────────────────────────────────────┐
    // │ (index) │      0       │                      1                       │
    // ├─────────┼──────────────┼──────────────────────────────────────────────┤
    // │    0    │    'STK'     │ '0x31ff3D6793916FEb6572A89faCCE19FFE2326052' │
    // │    1    │    'RTK'     │ '0x94d3eD27F0FA45F764421aDc08699aEB94aB64c9' │
    // │    2    │ 'LPGovernor' │ '0x92F538aE8202A1a229af2Df72d90e8C5C766Cef3' │
    // └─────────┴──────────────┴──────────────────────────────────────────────┘

    // ┌─────────┬──────────────┬──────────────────────────────────────────────┐
    // │ (index) │      0       │                      1                       │
    // ├─────────┼──────────────┼──────────────────────────────────────────────┤
    // │    0    │    'STK'     │ '0xda2DDAce49CDb2482F64CA292a61f9eD9c6f34BD' │ // clone 0x402AE5B2d3A531Deb1Bd9E34139dA72EeF961783
    // │    1    │    'RTK'     │ '0xdC473879f9AcB04aC0264a3A83CDD7B25E9B12d2' │
    // │    2    │ 'LPGovernor' │ '0x1ffDd5aeD1EF0F99DBC2279848CaBBc9B4063309' │
    // └─────────┴──────────────┴──────────────────────────────────────────────┘


    governor = await (await createFactory("TestLPGovernor")).attach("0x1ffDd5aeD1EF0F99DBC2279848CaBBc9B4063309")
    await governor.initialize("0x9Ba5Bd7b8dA996257746C5815392438b1c5eDe24", "0x402AE5B2d3A531Deb1Bd9E34139dA72EeF961783", "0xdC473879f9AcB04aC0264a3A83CDD7B25E9B12d2");
}

ethers.getSigners()
    .then(accounts => main(accounts))
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
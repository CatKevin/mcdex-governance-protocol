import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createFactory,
    createContract,
} from '../scripts/utils';

describe('DataExchange', () => {
    let l1Provder;
    let l1Signer;
    let l2Provder;
    let l2Signer;

    let TestAuthenticator;
    let TestDataExchange;

    let TEST_DATA_KEY = ethers.utils.id("TEST_DATA_KEY")

    before(async () => {

        TestAuthenticator = await createFactory("Authenticator");
        TestDataExchange = await createFactory("TestDataExchange");

        l1Provder = new ethers.providers.JsonRpcProvider("http://10.30.204.119:7545");
        l1Signer = new ethers.Wallet("dc1dfb1ba0850f1e808eb53e4c83f6a340cc7545e044f0a0f88c0e38dd3fa40d", l1Provder)

        l2Provder = new ethers.providers.JsonRpcProvider("http://10.30.204.119:8547");
        l2Signer = new ethers.Wallet("dc1dfb1ba0850f1e808eb53e4c83f6a340cc7545e044f0a0f88c0e38dd3fa40d", l2Provder)
    })

    it("deploy l1", async () => {
        return;

        const TestDataExchangeDeployer = await createFactory("TestDataExchangeDeployer");
        const l1Deployer = await TestDataExchangeDeployer.connect(l1Signer).deploy();
        console.log("l1Deployer", l1Deployer.address)

        const l1Exchange = await l1Deployer.connect(l1Signer).getAddress(998);
        await l1Deployer.connect(l1Signer).deploy2(998, { gasLimit: 8000000 });

        console.log("l1Exchange", l1Exchange);
    })


    it("deploy l2", async () => {

        return;

        const TestDataExchangeDeployer = await createFactory("TestDataExchangeDeployer");
        const l2Deployer = await TestDataExchangeDeployer.connect(l2Signer).deploy();
        console.log("l2Deployer", l2Deployer.address)

        const l2Exchange = await l2Deployer.connect(l2Signer).getAddress(1);
        await l2Deployer.connect(l2Signer).deploy2(1, { gasLimit: 8000000 });

        console.log("l2Exchange", l2Exchange);
    })

    it("step1 - create", async () => {
        return;

        const TestDataExchangeDeployer = await createFactory("TestDataExchangeDeployer");

        const l1Deployer = await TestDataExchangeDeployer.connect(l1Signer).deploy();
        console.log("l1Deployer", l1Deployer.address)

        const l1Exchange = await l1Deployer.connect(l1Signer).getAddress(998);
        console.log("l1Exchange", l1Exchange)
        await l1Deployer.connect(l1Signer).deploy2(998, { gasLimit: 8000000 });

        const l2Deplpyer = await TestDataExchangeDeployer.connect(l2Signer).deploy();
        console.log("l2Deployer", l2Deplpyer.address)

        const l2Exchange = await l2Deplpyer.connect(l2Signer).getAddress(998);
        console.log("l2Exchange", l2Exchange)
        await l2Deplpyer.connect(l2Signer).deploy2(998);

        // l1Deployer 0x203734b91a95C4C73058032538f492fa6A23C58e
        // l2Deployer 0x203734b91a95C4C73058032538f492fa6A23C58e

        // l1Exchange 0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7
        // l2Exchange 0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7
    })


    it("step2 - initialzie", async () => {
        return;

        const l1Auth = await TestAuthenticator.connect(l1Signer).deploy();
        console.log("l1Auth", l1Auth.address);
        const l2Auth = await TestAuthenticator.connect(l2Signer).deploy();
        console.log("l2Auth", l2Auth.address);

        const l1Exchange = await TestDataExchange.attach("0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7");
        await l1Exchange.initialize(l1Auth.address);

        const l2Exchange = await TestDataExchange.attach("0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7");
        await l2Exchange.initialize(l2Auth.address);

        // l1Auth 0x67E6A7D50dd6D06a7Db2AF0896E84782e98866F5
        // l2Auth 0x67E6A7D50dd6D06a7Db2AF0896E84782e98866F5
    })

    it("step2 - auth", async () => {
        return;

        // const l1Auth = await TestAuthenticator.attach("0xb84E6E28d15cbc0f27897a02cC3a8fB88ba227f6")
        const l2Auth = await TestAuthenticator.attach("0x67E6A7D50dd6D06a7Db2AF0896E84782e98866F5")
        await l2Auth.connect(l2Signer).initialize();

        const l2Exchange = await TestDataExchange.attach("0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7");

        console.log(await l2Exchange.authenticator());

        var tx = await l2Exchange.connect(l2Signer).updateDataSource(TEST_DATA_KEY, l1Signer.address);
        await tx.wait()
        console.log("txhash", tx);

        // var tx = await l2Exchange.connect(l2Signer).updateDataSource(TEST_DATA_KEY, l2Signer.address);
        // await tx.wait()

    })


    it("step2 - l1->l2", async () => {
        return;

        const l1Exchange = await TestDataExchange.attach("0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7");
        const l2Exchange = await TestDataExchange.attach("0x9436d469F74b0f1b731345eF39F179E36D5f3Fc7");

        await l2Exchange.connect(l2Signer).updateDataSource(TEST_DATA_KEY, l1Signer.address);
        await l2Exchange.connect(l2Signer).updateDataSource(TEST_DATA_KEY, l2Signer.address);
    })
})
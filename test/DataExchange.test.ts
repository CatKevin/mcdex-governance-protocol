import { expect } from "chai";
import { hexStripZeros } from "_@ethersproject_bytes@5.0.8@@ethersproject/bytes";
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

    })

    it("no ether", async () => {
        const dataExchange = await createContract("DataExchange");

        const user = (await getAccounts())[0]
        console.log(user)
        await expect(user.sendTransaction({
            value: 1,
            to: dataExchange.address,
        })).to.be.revertedWith("contract doesn't accept ether")
    })
})
import { expect } from "chai";
const { ethers } = require("hardhat");
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
} from '../scripts/utils';

describe('Authenticator', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;

    let DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000";

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    it("transfer admin", async () => {

        const auth = await createContract("Authenticator");
        await auth.initialize();

        expect(await auth.hasRole(DEFAULT_ADMIN_ROLE, user0.address)).to.be.true;
        expect(await auth.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.false;

        // to user1
        await auth.grantRole(DEFAULT_ADMIN_ROLE, user1.address);
        await auth.renounceRole(DEFAULT_ADMIN_ROLE, user0.address);

        expect(await auth.hasRole(DEFAULT_ADMIN_ROLE, user0.address)).to.be.false;
        expect(await auth.hasRole(DEFAULT_ADMIN_ROLE, user1.address)).to.be.true;
    })

    it("role or admin", async () => {
        const auth = await createContract("Authenticator");
        await auth.initialize();

        let TMP_ADMIN_ROLE = "0xffff000000000000000000000000000000000000000000000000000000000000";

        await auth.grantRole(TMP_ADMIN_ROLE, user1.address);

        expect(await auth.hasRole(TMP_ADMIN_ROLE, user1.address)).to.be.true;
        expect(await auth.hasRole(TMP_ADMIN_ROLE, user0.address)).to.be.false;
        expect(await auth.hasRoleOrAdmin(TMP_ADMIN_ROLE, user1.address)).to.be.true;
        expect(await auth.hasRoleOrAdmin(TMP_ADMIN_ROLE, user0.address)).to.be.true;
    });
})
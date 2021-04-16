import { expect } from "chai";
import {
    toWei,
    fromWei,
    toBytes32,
    getAccounts,
    createContract,
    createFactory,
} from '../scripts/utils';

describe('Minter', () => {
    let accounts;
    let user0;
    let user1;
    let user2;
    let user3;
    let seriesA;
    let vault;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        seriesA = accounts[4];
    })

    it("constructor", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        await expect(createContract("TestMinter", [
            user0.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ])).to.be.revertedWith("token must be contract");

        await expect(createContract("TestMinter", [
            mcb.address,
            user0.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ])).to.be.revertedWith("data exchange must be contract");
    })

    it("mint - no caputre value", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        const minter = await createContract("TestMinter", [
            mcb.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0"))

        await minter.setBlockNumber(1)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0.2"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("2"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("2"))

        await dataExchange.setTotalCapturedUSD(toWei("0.4"), 1);  // min = 0.2 extra = 0.2
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0.2"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0.2"))

        await dataExchange.setTotalCapturedUSD(toWei("1.0"), 1);  // min 0.2 + extra1 0.55392 + extra2 (1-0.2-0.55392)
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0.55392"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0.44608"))
    })

    it("mint - base -> series-a -> base", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        const minter = await createContract("TestMinter", [
            mcb.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.5"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0"))

        await dataExchange.setTotalCapturedUSD(toWei("6000000"), 1);
        await minter.setBlockNumber(1)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0.5"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("5000000"))
        // await minter.updateMintableAmount();
        // expect(await minter.callStatic.totalCapturedValue()).to.equal(toWei("6000000"))

        await minter.setBlockNumber(10)
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("5"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("5000000"))

        await dataExchange.setTotalCapturedUSD(toWei("8000000"), 10000000);  // min = 0.2 extra = 0.2
        await minter.setBlockNumber(10000000)
        // extra = 8000000 - 20000000 = 6000000
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("5000000"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("3000000"))

        await dataExchange.setTotalCapturedUSD(toWei("1"), 1);  // min = 0.2 extra = 0.2
        await minter.setBlockNumber(1)
        await minter.updateMintableAmount();
        // 0.8 - 0.5
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0.5"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0.5")) // 0.2 + 0.3
        expect(await minter.callStatic.extraMintableAmount()).to.equal(toWei("0.3"))

        await minter.setBlockNumber(2)
        await minter.updateSeriesAMintableAmount();
        expect(await minter.callStatic.updateAndGetSeriesAMintableAmount()).to.equal(toWei("0.8"))
        expect(await minter.callStatic.updateAndGetBaseMintableAmount()).to.equal(toWei("0.4")) // 0.2 + 0.3
        expect(await minter.callStatic.extraMintableAmount()).to.equal(toWei("0"))
    })

    it("change dev account", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        const minter = await createContract("TestMinter", [
            mcb.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5000000"),
            toWei("5000000"),
            toWei("0.2"),
            toWei("0.55392"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.connect(user2).setDevAccount(user3.address);
        expect(await minter.devAccount()).to.equal(user3.address);
        await expect(minter.setDevAccount(user3.address)).to.be.revertedWith("caller must be dev account")
        await expect(minter.connect(user3).setDevAccount(user3.address)).to.be.revertedWith("already dev account")
    })

    it("mockcase ", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        const minter = await createContract("TestMinter", [
            mcb.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5"),
            toWei("5"),
            toWei("0.2"),
            toWei("0.3"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0"))

        await dataExchange.setTotalCapturedUSD(toWei("1.5"), 1);
        await minter.setBlockNumber(2)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.6")) // max(0.3 * 2, extra)
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("1.1")) // 0.2 * 2 + 0.7
        expect(await minter.extraMintableAmount()).to.equal(toWei("0.7"))  // 1.5 - 0.2 * 1 - 0.6
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.4"))  // 1.5 - 0.2 * 1 - 0.6

        await minter.testSeriesAMint(user2.address, toWei("0.6"))

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0")) // 0.6 - 0.6
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("1.1"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("0.7"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.4"))  // 1.5 - 0.2 * 1 - 0.6
        expect(await minter.seriesAMintedAmount()).to.equal(toWei("0.6"))

        await minter.testBaseMint(user2.address, toWei("0.2"))

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0.9")) // 1.1 - 0.2
        expect(await minter.extraMintableAmount()).to.equal(toWei("0.7"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.2"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("0.2"))

        await minter.testBaseMint(user2.address, toWei("0.9"))

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0")) // 0.9 - 0.9
        expect(await minter.extraMintableAmount()).to.equal(toWei("0"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("1.1"))

        await dataExchange.setTotalCapturedUSD(toWei("5"), 2); // +3.5
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("3.3")) // extra
        expect(await minter.extraMintableAmount()).to.equal(toWei("3.3")) // 3.5 - 0.2
        expect(await minter.baseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("1.1")) // 3.3 + 1.1 = 4.4

        await dataExchange.setTotalCapturedUSD(toWei("6"), 3); // +1
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("3.9")) // extra
        expect(await minter.extraMintableAmount()).to.equal(toWei("4.1")) // 3.3 + 1 - 0.2
        expect(await minter.baseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("1.1")) // 3.3 + 1.1 = 4.4

        await minter.setBlockNumber(3)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.3"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("3.9")) // min(3.8 + 0.2, 3.9)
        expect(await minter.extraMintableAmount()).to.equal(toWei("3.8")) // 4.1 - 0.3
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.2"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("1.1")) // 3.3 + 1.1 = 4.4

        await minter.testBaseMint(user2.address, toWei("3.9"))

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.3"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0")) // min(3.8 + 0.2, 3.9)
        expect(await minter.extraMintableAmount()).to.equal(toWei("0.1")) // 4.1 - 0.3
        expect(await minter.baseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("5")) // 3.3 + 1.1 = 4.4

        await minter.setBlockNumber(4)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.4"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0")) // min(3.8 + 0.2, 3.9)
        expect(await minter.extraMintableAmount()).to.equal(toWei("0")) // 4.1 - 0.3
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.2"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("5")) // 3.3 + 1.1 = 4.4

        await minter.setBlockNumber(5)
        await dataExchange.setTotalCapturedUSD(toWei("7"), 4); // +1
        await minter.updateMintableAmount();
        // await minter.updateSeriesAMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.7"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("0.5"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.4")) // 0.2
        expect(await minter.baseMintedAmount()).to.equal(toWei("5"))

        await minter.setBlockNumber(6)
        await dataExchange.setTotalCapturedUSD(toWei("1000"), 5); // +993
        await minter.updateMintableAmount();
        // await minter.updateSeriesAMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("1"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("993"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.6")) // 0.2
        expect(await minter.baseMintedAmount()).to.equal(toWei("5"))

        await minter.setBlockNumber(26)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("4.4"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("989.6"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("4.6"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("5"))
        expect(await minter.seriesAMintedAmount()).to.equal(toWei("0.6"))

        await minter.testSeriesAMint(user2.address, toWei("4.4"))

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("989.6"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("4.6"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("5"))
        expect(await minter.seriesAMintedAmount()).to.equal(toWei("5"))

        await minter.setBlockNumber(36)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))
        expect(await minter.extraMintableAmount()).to.equal(toWei("989.6"))
        expect(await minter.baseMintableAmount()).to.equal(toWei("6.6"))
        expect(await minter.baseMintedAmount()).to.equal(toWei("5"))
        expect(await minter.seriesAMintedAmount()).to.equal(toWei("5"))
    })


    it("mockcase - series-a mint all", async () => {
        const mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        const dataExchange = await createContract("MockDataExchange");

        const minter = await createContract("TestMinter", [
            mcb.address,
            dataExchange.address,
            seriesA.address,
            user2.address,
            toWei("5"),
            toWei("5"),
            toWei("0.2"),
            toWei("0.3"),
        ]);
        await mcb.grantRole(await mcb.MINTER_ROLE(), minter.address);

        await minter.setBlockNumber(0)
        expect(await minter.callStatic.getSeriesAMintableAmount()).to.equal(toWei("0"))
        expect(await minter.callStatic.getBaseMintableAmount()).to.equal(toWei("0"))

        await dataExchange.setTotalCapturedUSD(toWei("6.5"), 1);
        await minter.setBlockNumber(2)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0.6")) // max(0.3 * 2, extra)
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("5")) // 0.2 * 2 + 0.7
        expect(await minter.extraMintableAmount()).to.equal(toWei("5.7"))  // 6.5 - 0.2 - 0.6
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.4"))  // 1.5 - 0.2 * 1 - 0.6

        await minter.setBlockNumber(20)
        await minter.updateSeriesAMintableAmount();

        // base not updated
        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("5")) // max(0.3 * 2, extra)
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("1.7"))  //
        expect(await minter.extraMintableAmount()).to.equal(toWei("1.3"))  //
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.4"))  // 20 * 0.2

        await minter.updateMintableAmount();

        // base not updated
        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("5")) // max(0.3 * 2, extra)
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("5"))  //
        expect(await minter.extraMintableAmount()).to.equal(toWei("1.3"))  //
        expect(await minter.baseMintableAmount()).to.equal(toWei("4"))  // 20 * 0.2

        await minter.testSeriesAMint(user2.address, toWei("5"))
        await minter.testBaseMint(user2.address, toWei("5"))

        await expect(minter.testSeriesAMint(user2.address, toWei("1"))).to.be.revertedWith("exceeds max")
        await expect(minter.testBaseMint(user2.address, toWei("1"))).to.be.revertedWith("exceeds max")

        await dataExchange.setTotalCapturedUSD(toWei("7.5"), 2);
        await minter.setBlockNumber(21)
        await minter.updateMintableAmount();

        expect(await minter.getSeriesAMintableAmount()).to.equal(toWei("0")) // max(0.3 * 2, extra)
        expect(await minter.getBaseMintableAmount()).to.equal(toWei("0"))  //
        expect(await minter.extraMintableAmount()).to.equal(toWei("1.1"))  // 0.3 + 0.8
        expect(await minter.baseMintableAmount()).to.equal(toWei("0.2"))  // 20 * 0.2
    })

})

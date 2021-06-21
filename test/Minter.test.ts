const { ethers } = require("hardhat");
import { expect, use } from "chai";
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

    let mcb;
    let auth;
    let valueCapture;
    let minter;

    before(async () => {
        accounts = await getAccounts();
        user0 = accounts[0];
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
    })

    beforeEach(async () => {
        auth = await createContract("Authenticator");
        await auth.initialize();

        mcb = await createContract("CustomERC20", ["MCB", "MCB", 18]);
        minter = await createContract("TestMCBMinter")
        await minter.initialize(
            auth.address,
            mcb.address,
            user1.address,
            100,
            toWei("2000000"),
            toWei("0.2")
        );
        valueCapture = await createContract("TestValueCapture", [minter.address])

        await mcb.grantRole(ethers.utils.id("MINTER_ROLE"), minter.address)
        await auth.grantRole(ethers.utils.id("VALUE_CAPTURE_ROLE"), valueCapture.address)
    })

    const isDefined = (x) => {
        return typeof x != 'undefined'
    }

    const caseTester = async (contracts, cases, isNonStatic = false) => {
        const runCase = async (element, isNonStatic) => {
            if (isDefined(element.name)) {
                console.log("         - CASE =>", element.name)
            } else {
                console.log("         - CASE", i)
            }
            // console.log(element)
            if (isDefined(element.block)) {
                // console.log("setBlockNumber")
                await contracts.minter.setBlockNumber(element.block)
            }
            if (isDefined(element.capture)) {
                // console.log("setCapturedUSD")
                await contracts.valueCapture.setCapturedUSD(element.capture[1], element.capture[0])
            }
            if (isNonStatic) {
                await contracts.minter.updateMintableAmount();
            }
            const { baseMintableAmount, roundMintableAmounts } = await minter.callStatic.getMintableAmounts()
            if (isDefined(element.base)) {
                // console.log("checkBase")
                expect(baseMintableAmount, `${i}.base missmatch`).to.equal(element.base)
            }
            if (isDefined(element.extra)) {
                // console.log("checkExtra")
                expect(await minter.extraMintableAmount(), `${i}.extra missmatch`).to.equal(element.extra)
            }
            if (isDefined(element.rounds)) {
                // console.log("checkRounds")
                for (var j = 0; j < element.rounds.length; j++) {
                    expect(roundMintableAmounts[j], `${i}.round.${j} missmatch`).to.equal(element.rounds[j])
                }
            }
        }
        console.log(`       ${isNonStatic ? "NON-STATIC CASES" : "STATIC CASES"}`)
        for (var i = 0; i < cases.length; i++) {

            await runCase(cases[i], isNonStatic)
        }
    }

    it("reinitialize", async () => {
        await expect(minter.initialize(
            auth.address,
            mcb.address,
            user1.address,
            100,
            toWei("2000000"),
            toWei("0.2")
        )).to.be.revertedWith("contract is already initialized");
    })

    it("base release", async () => {
        await minter.setBlockNumber(1) // < 100
        await caseTester({ minter, valueCapture }, [
            {
                base: 0,
                extra: 0,
            },
            {
                block: 101,
                base: toWei("0.2"),
            },
            {
                block: 1110,
                base: toWei("202"),
            },
            {
                block: 40000099,
                base: toWei("7999999.8"),
            },
            {
                block: 40000100,
                base: toWei("8000000"),
            },
            {
                block: 50000100,
                base: toWei("8000000"),
            },
        ])
    })

    it("base mint", async () => {
        await minter.setBlockNumber(1110) // < 100
        const { baseMintableAmount, } = await minter.callStatic.getMintableAmounts()
        expect(baseMintableAmount).to.equal(toWei("202"))
        {
            await expect(minter.connect(user2).mintFromBase(user2.address, toWei("200"))).to.be.revertedWith("caller is not authorized")
            expect(await mcb.balanceOf(user3.address)).to.equal(toWei("0"))
            await minter.mintFromBase(user3.address, toWei("200"))
            expect(await mcb.balanceOf(user3.address)).to.equal(toWei("150"))
            expect(await mcb.balanceOf(user1.address)).to.equal(toWei("50"))
        }
        {
            const { baseMintableAmount, } = await minter.callStatic.getMintableAmounts()
            expect(baseMintableAmount).to.equal(toWei("2"))
            expect(await mcb.balanceOf(user3.address)).to.equal(toWei("150"))
            await minter.mintFromBase(user3.address, toWei("2"))
            expect(await mcb.balanceOf(user3.address)).to.equal(toWei("151.5"))
            expect(await mcb.balanceOf(user1.address)).to.equal(toWei("50.5"))
        }
        {
            const { baseMintableAmount, } = await minter.callStatic.getMintableAmounts()
            expect(baseMintableAmount).to.equal(toWei("0"))
            await expect(minter.mintFromBase(user3.address, toWei("1"))).to.be.revertedWith("amount exceeds max mintable amount")
        }
        {
            // surpass max base supply
            await minter.setBlockNumber(50000100) // < 100
            const { baseMintableAmount, } = await minter.callStatic.getMintableAmounts()
            expect(baseMintableAmount).to.equal(toWei("7999798"))
        }
    })

    it("extra mintable", async () => {
        await caseTester({ minter, valueCapture }, [
            {
                base: 0,
                extra: 0,
            },
            {
                block: 101,
                base: toWei("0.2"),
                extra: 0
            },
            {
                block: 110,
                capture: [105, toWei("2")],
                extra: toWei("1"),
                base: toWei("3"),
            },
            {
                capture: [115, toWei("96")],
                extra: toWei("93"),
                base: toWei("95"),
            },
            {
                block: 115,
                extra: toWei("93"),
                base: toWei("96"),
            },
        ])
    })

    it("round mint - 2", async () => {
        await minter.setBlockNumber(1) // < 100
        await minter.newRound(
            user2.address,
            toWei("700000"),
            toWei("0.5"),
            110,
        )
        await caseTester({ minter, valueCapture }, [
            {
                base: 0,
                extra: 0,
                rounds: [0]
            },
            {
                block: 110,
                base: toWei("2"),
                extra: 0,
                rounds: [0]
            },
            {
                capture: [110, toWei("20")],
                base: toWei("20"),
                extra: toWei("18"),
                rounds: [0]
            },
            {
                block: 120,
                capture: [120, toWei("30")],
                extra: toWei("26"),
                base: toWei("25"),
                rounds: [toWei("5")]
            },
            {
                block: 130,
                capture: [120, toWei("30")],
                extra: toWei("26"),
                base: toWei("27"),
                rounds: [toWei("5")]
            },
            {
                block: 130,
                capture: [130, toWei("30")],
                extra: toWei("26"),
                base: toWei("22"),
                rounds: [toWei("10")]
            },
        ])
    })

    it("round mint - more rounds | static", async () => {
        await minter.setBlockNumber(1) // < 100
        // round - 0
        await minter.newRound(
            user2.address,
            toWei("700000"),
            toWei("0.5"),
            110,
        )
        // round - 1
        await minter.newRound(
            user2.address,
            toWei("200000"),
            toWei("0.2"),
            150,
        )
        await caseTester({ minter, valueCapture }, [
            {
                base: 0,
                extra: 0,
                rounds: [0]
            },
            {
                block: 110,
                extra: 0,
                base: toWei("2"),
                rounds: [0]
            },
            {
                capture: [110, toWei("20")],
                extra: toWei("18"),
                base: toWei("20"),
                rounds: [0]
            },
            {
                block: 120,
                capture: [120, toWei("30")],
                extra: toWei("26"),
                base: toWei("25"),
                rounds: [toWei("5"), toWei("0")]
            },
            {
                block: 160,
                extra: toWei("26"),
                base: toWei("33"), // + 40 * 0.2 = 6
                rounds: [toWei("5"), toWei("0")]
            },
            {
                capture: [150, toWei("50")],
                extra: toWei("40"), // t = 30 * 0.2 = 6, +e = 20 - 6
                base: toWei("32"), // + 40 * 0.2 = 6
                rounds: [toWei("20"), toWei("0")] // 30 * 0.5
            },
            {
                capture: [160, toWei("50")],
                extra: toWei("40"), // t = 10 * 0.2 = 2, +e = 0
                base: toWei("25"), // + 40 * 0.2 = 6
                rounds: [toWei("25"), toWei("2")] // 30 * 0.5
            },
            {
                capture: [1400109, toWei("10000000")],
                extra: toWei("9720000.2"), // t = 1399949 * 0.2 = 280001.8, +e = 9999950 - 279989.8
                rounds: [toWei("699999.5"), toWei("200000")] // 30 * 0.5
            },
            {
                capture: [1400110, toWei("10000000")],
                rounds: [toWei("700000"), toWei("200000")] // 30 * 0.5
            },
            {
                capture: [1401110, toWei("11000000")],
                rounds: [toWei("700000"), toWei("200000")] // 30 * 0.5
            },
        ])
    })

    it("round mint - more rounds | non-static", async () => {
        await minter.setBlockNumber(1) // < 100
        // round - 0
        await minter.newRound(
            user2.address,
            toWei("700000"),
            toWei("0.5"),
            110,
        )
        // round - 1
        await minter.newRound(
            user2.address,
            toWei("200000"),
            toWei("0.2"),
            150,
        )
        await caseTester({ minter, valueCapture }, [
            {
                base: 0,
                extra: 0,
                rounds: [0]
            },
            {
                block: 110,
                base: toWei("2"),
                extra: 0,
                rounds: [0]
            },
            {
                capture: [110, toWei("20")],
                extra: toWei("18"),
                base: toWei("20"),
                rounds: [0]
            },
            ///////////////////////
            {
                block: 120,
                capture: [120, toWei("30")],
                extra: toWei("21"),
                base: toWei("25"),
                rounds: [toWei("5"), toWei("0")]
            },
            ///////////////////////
            {
                block: 160,
                extra: toWei("21"),
                base: toWei("33"), // + 40 * 0.2
                rounds: [toWei("5"), toWei("0")]
            },
            {
                capture: [150, toWei("50")],
                extra: toWei("20"), // 21 + 20 - 30 * 0.2 = 41 - 6 = 35 //
                base: toWei("32"),
                rounds: [toWei("20"), toWei("0")] // 30 * 0.5
            },
            {
                capture: [160, toWei("50")],
                extra: toWei("13"), // 20 -5 -2
                base: toWei("25"), // + 40 * 0.2 = 6
                rounds: [toWei("25"), toWei("2")] // 30 * 0.5
            },
            {
                capture: [1400109, toWei("10000000")],
                rounds: [toWei("699999.5"), toWei("200000")] // 30 * 0.5
            },
            {
                capture: [1400110, toWei("10000000")],
                rounds: [toWei("700000"), toWei("200000")] // 30 * 0.5
            },
            {
                capture: [1401110, toWei("11000000")],
                rounds: [toWei("700000"), toWei("200000")] // 30 * 0.5
            },
        ], true)
    })
})

const hre = require("hardhat")
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { restorableEnviron } from './deployer/environ'
import { sleep, ensureFinished, printInfo, printError } from './deployer/utils'

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
        WETH9: "0xd0A1E359811322d97991E03f863a0C30C2cF029C",
    }
}

async function deployDataExchange(deployer, authenticator) {
    const l1Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:7545")
    const l2Provider = new ethers.providers.JsonRpcProvider("http://10.30.204.119:8547")

    let privateKey = ethers.utils.randomBytes(32)
    let l1Wallet = new ethers.Wallet(privateKey, l1Provider)
    let l2Wallet = new ethers.Wallet(privateKey, l2Provider)

    // send deployment funds
    const ownerWallet = hre.ethers.provider.getSigner(0);
    const feeTx = await ensureFinished(hre.ethers.provider.getSigner(0).sendTransaction({
        to: l1Wallet.address,
        value: toWei("0.1"),
        gasLimit: 25000,
    }))
    let l1Deployed
    let l2Deployed
    try {
        l1Deployed = await deployer.deployWith(l1Wallet, "DataExchange")
        l2Deployed = await deployer.deployWith(l2Wallet, "DataExchange")
        await ensureFinished(l1Deployed.initialize(authenticator.address))
        await ensureFinished(l2Deployed.initialize(authenticator.address))
        return { l1DataExchange: l1Deployed, l2DataExchange: l2Deployed }
    } catch (err) {
        printError(err)
        throw err
    } finally {
        // refund deployment funds
        let refund = await l1Wallet.getBalance()
        printInfo(`${refund} left`)
        const transferCost = ethers.BigNumber.from(feeTx.gasPrice).mul(ethers.BigNumber.from(25000))
        // printInfo(`${transferCost} for transfer fee`)
        if (refund.gt(transferCost)) {
            refund = refund.sub(transferCost)
            printInfo(`refund ${refund} to ${await ownerWallet.getAddress()}`);
            await l1Wallet.sendTransaction({
                to: await ownerWallet.getAddress(),
                value: refund,
                gasLimit: 25000,
                gasPrice: feeTx.gasPrice,
            })

        }
    }
}

async function main(deployer, accounts) {
    await hre.run("compile");

    const owner = accounts[0]
    // authenticator
    printInfo("creating Authenticator ...")
    const authenticator = await deployer.deploy("Authenticator")
    await ensureFinished(authenticator.initialize());
    printInfo("done")

    // data exchange
    printInfo("creating DataExchange ...")
    await deployDataExchange(deployer, authenticator);
    printInfo("done")

    // fake mcb
    printInfo("creating Test MCB ...")
    const mcb = await deployer.deployAs("CustomERC20", "MCB", "MCB", "MCB", 18);
    printInfo("done")

    // xmcb
    printInfo("creating XMCB ...")
    const xmcb = await deployer.deploy("XMCB");
    await ensureFinished(xmcb.initialize(
        deployer.addressOf("Authenticator"),
        deployer.addressOf("MCB"),
        toWei("0.05")
    ))
    printInfo("done")

    // timelock & governor
    printInfo("creating Voting System ...")
    const timelock = await deployer.deploy("Timelock", owner.address, 0);
    const governor = await deployer.deploy(
        "FastGovernorAlpha",
        deployer.addressOf("DataExchange"),
        deployer.addressOf("Timelock"),
        deployer.addressOf("XMCB"),
        owner.address
    );

    // set admin to governor && restore delay
    const eta = (await ethers.provider.getBlock()).timestamp + 10;
    await ensureFinished(timelock.queueTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    ))
    await ensureFinished(timelock.queueTransaction(
        timelock.address,
        0,
        "setDelay(uint256)",
        ethers.utils.defaultAbiCoder.encode(["uint256"], [300]),
        eta
    ))
    await sleep(10000)

    await ensureFinished(timelock.executeTransaction(
        timelock.address,
        0,
        "setPendingAdmin(address)",
        ethers.utils.defaultAbiCoder.encode(["address"], [governor.address]),
        eta
    ))
    await ensureFinished(timelock.executeTransaction(
        timelock.address,
        0,
        "setDelay(uint256)",
        ethers.utils.defaultAbiCoder.encode(["uint256"], [300]),
        eta
    ))

    await ensureFinished(governor.__acceptAdmin())
    printInfo("done")

    // vault
    printInfo("creating Vault ...")
    const vault = await deployer.deploy("Vault");
    await ensureFinished(vault.initialize(authenticator.address));
    printInfo("done")

    // value capture
    printInfo("creating Vault Capture ...")
    const valueCapture = await deployer.deploy("ValueCapture");
    await ensureFinished(valueCapture.initialize(authenticator.address, deployer.addressOf("DataExchange"), vault.address));
    await ensureFinished(authenticator.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", timelock.address));
    printInfo("done")

    // test in & out
    printInfo("creating Test Token Seller ...")
    const tokenIn1 = await deployer.deployAs("CustomERC20", "TKN1", "TKN1", "TKN1", 18);
    const tokenOu1 = await deployer.deployAs("CustomERC20", "USD1", "USD1", "USD1", 18);

    // a mock convertor
    const seller1 = await deployer.deploy("ConstantSeller", tokenIn1.address, tokenOu1.address, toWei("4"))
    const oracle = await deployer.deploy("MockTWAPOracle");
    await ensureFinished(oracle.setPrice(toWei("5")))

    await ensureFinished(valueCapture.addUSDToken(tokenOu1.address, 18))
    await ensureFinished(valueCapture.setConvertor(tokenIn1.address, oracle.address, seller1.address, toWei("0.01")))
    printInfo("done")

    // reward distrubution && start mining
    printInfo("creating Reward Distribution ...")
    const rewardDistrubution = await deployer.deploy("TestRewardDistribution", authenticator.address, xmcb.address);
    await ensureFinished(xmcb.addComponent(rewardDistrubution.address));
    await ensureFinished(rewardDistrubution.createRewardPlan(mcb.address, toWei("0.2")))
    await ensureFinished(rewardDistrubution.notifyRewardAmount(mcb.address, toWei("20000")))
    printInfo("done")

    printInfo("creating Minter ...")
    await deployer.deploy("Minter",
        mcb.address,
        deployer.addressOf("DataExchange"),
        owner.address,
        owner.address,
        toWei("5000000"),
        toWei("5000000"),
        toWei("0.2"),
        toWei("0.55392"),
    )
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
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

    }
}

// onL1
async function main(deployer, accounts) {
    const owner = accounts[0]

    // authenticator
    printInfo("creating Authenticator ...")
    const authenticator = await deployer.deploy("Authenticator")
    await ensureFinished(authenticator.initialize());
    printInfo("done")

    // fake mcb
    // const l1Provider = new ethers.providers.JsonRpcProvider(hre.network.config.urlL1)
    // const l1Wallet = new ethers.Wallet(hre.network.config.accounts[0], l1Provider)
    printInfo("creating Test MCB ...")
    const mcb = await deployer.deploy("MCB", "fakeMCB", "fakeMCB", 18);
    printInfo("done")

    printInfo("creating dataExchange ...")
    const dataExchange = await deployer.deploy("MockDataExchange")
    printInfo("done")

    printInfo("creating XMCB ...")
    const xmcb = await deployer.deploy("XMCB");
    await ensureFinished(xmcb.initialize(
        deployer.addressOf("Authenticator"),
        deployer.addressOf("MCB"),
        toWei("0.05")
    ))
    printInfo("done")

    printInfo("creating Voting System ...")
    console.log(owner.address)
    const timelock = await deployer.deploy("Timelock", owner.address, 0);
    const governor = await deployer.deploy(
        "FastGovernorAlpha",
        deployer.addressOf("MockDataExchange"),
        deployer.addressOf("Timelock"),
        deployer.addressOf("XMCB"),
        owner.address,
        22
    );
    // set admin to governor && restore delay
    // const eta = (await ethers.provider.getBlock()).timestamp + 10;
    const eta = Math.floor(Date.now() / 1000)
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
    await sleep(20000)
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
    await ensureFinished(valueCapture.initialize(authenticator.address, deployer.addressOf("MockDataExchange"), vault.address));
    await ensureFinished(authenticator.grantRole("0x0000000000000000000000000000000000000000000000000000000000000000", deployer.addressOf("Timelock")));
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
    await ensureFinished(rewardDistrubution.createRewardPlan(deployer.addressOf("MCB"), toWei("0.2")))
    await ensureFinished(rewardDistrubution.notifyRewardAmount(deployer.addressOf("MCB"), toWei("20000")))
    printInfo("done")

    printInfo("creating Minter ...")
    const mintInitiator = await deployer.deploy("MockMintInitiator")
    await deployer.deploy(
        "MockMinter",
        deployer.addressOf("MockMintInitiator"),
        deployer.addressOf("MCB"),
        deployer.addressOf("MockDataExchange"),
        owner.address,
        owner.address,
        toWei("4000000"),
        toWei("4000000"),
        toWei("0.2"),
        toWei("0.55392"),
    )
    await mintInitiator.initialize(deployer.addressOf("Authenticator"), deployer.addressOf("MockMinter"))
    printInfo("done")
}

ethers.getSigners()
    .then(accounts => restorableEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });
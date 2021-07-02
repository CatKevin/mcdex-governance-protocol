const hre = require("hardhat");
const chalk = require("chalk");
const ethers = hre.ethers;

import { DeploymentOptions } from "./deployer/deployer";
import { readOnlyEnviron } from "./deployer/environ";
import { printError } from "./deployer/utils";

function passOrWarn(title, cond) {
  return cond ? chalk.greenBright(title) : chalk.red(title);
}

function highLight(text) {
  return chalk.greenBright(text);
}

function fromWei(n) {
  return ethers.utils.formatEther(n);
}

const ENV: DeploymentOptions = {
  network: hre.network.name,
  artifactDirectory: "./artifacts/contracts",
  addressOverride: {},
};

async function verifyArguments(deployer, accounts) {
  const xmcb = await deployer.getDeployedContract("XMCB");
  const vault = await deployer.getDeployedContract("Vault");
  const valueCapture = await deployer.getDeployedContract("ValueCapture");
  const mcbMinter = await deployer.getDeployedContract("MCBMinter");
  const timelock = await deployer.getDeployedContract("Timelock");
  const governor = await deployer.getDeployedContract("GovernorAlpha");
  const rewardDistribution = await deployer.getDeployedContract("RewardDistribution");

  console.log("XMCB:");
  console.log("========================");
  console.log("  -", `withdrawalPenaltyRate ${highLight(fromWei(await xmcb.withdrawalPenaltyRate()) * 100)} %`);
  console.log("  -", `rawToken (deposit)    ${highLight(await xmcb.rawToken())}`);

  const componentCount = await xmcb.componentCount();
  const components = await xmcb.listComponents(0, componentCount + 1);
  console.log(`  - found ${componentCount} components`);
  for (var i = 0; i < componentCount; i++) {
    console.log(`    - ${i}. ${components[i]}`);
  }

  console.log("Governor:");
  console.log("========================");
  console.log("  -", `mcbToken              ${highLight(await governor.mcbToken())}`);
  console.log("  -", `quorumVotes           ${highLight(fromWei(await governor.quorumVotes()))} MCB`);
  console.log("  -", `proposalThreshold     ${highLight(fromWei(await governor.proposalThreshold()))} MCB`);
  console.log("  -", `proposalMaxOperations ${highLight(await governor.proposalMaxOperations())}`);
  console.log("  -", `votingDelay           ${highLight(await governor.votingDelay())} blocks`);
  console.log("  -", `votingPeriod          ${highLight(await governor.votingPeriod())} blocks`);
  console.log("  -", `guardian              ${highLight(await governor.guardian())}`);
  console.log("  -", `timelockDelay         ${highLight(await timelock.delay())} seconds`);
  console.log("  -", `timelockGracePeriod   ${highLight(await timelock.GRACE_PERIOD())} seconds`);
  console.log("  -", `timelockAdmin         ${highLight(await timelock.admin())}`);

  console.log("ValueCapture:");
  console.log("========================");
  const usdTokens = await valueCapture.listUSDTokens(0, 888);
  console.log(`  - found ${usdTokens.length} usdTokens`);
  for (var i = 0; i < usdTokens.length; i++) {
    console.log(`    - ${i}. ${usdTokens[i]}`);
  }
  console.log("  -", `vault                 ${highLight(await valueCapture.vault())}`);
  console.log("  -", `notificationRecipient ${highLight(await valueCapture.captureNotifyRecipient())}`);
}

async function verifyRoles(deployer, accounts) {
  const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000";

  const fetchRoleAccounts = async (contract, granted, roleName, roleValue) => {
    console.log(" ", roleName, `[ ${roleValue} ]`);
    const roleCount = (await contract.getRoleMemberCount(roleValue)).toNumber();
    granted[roleName] = [];
    for (var j = 0; j < roleCount; j++) {
      const account = await contract.getRoleMember(roleValue, j);
      console.log(`  - ${account}`);
      granted[roleName].push(account);
    }
  };

  // authenticator
  const authenticator = await deployer.getDeployedContract("Authenticator");
  const granted = {};

  console.log("Authenticator Granted:");
  console.log("========================");
  const authenticatorRoles = ["VALUE_CAPTURE_ADMIN_ROLE", "XMCB_ADMIN_ROLE", "MINTER_ADMIN_ROLE", "VALUE_CAPTURE_ROLE"];
  // admin
  await fetchRoleAccounts(authenticator, granted, "DEFAULT_ADMIN_ROLE", adminRole);
  // sub-roles
  for (var i = 0; i < authenticatorRoles.length; i++) {
    const roleName = authenticatorRoles[i];
    const roleValue = ethers.utils.id(roleName);
    await fetchRoleAccounts(authenticator, granted, roleName, roleValue);
  }

  const mcb = await deployer.getDeployedContract("MCB");
  const mcbGranted = {};
  const mcbRoles = ["MINTER_ROLE"];
  console.log("MCB Granted:");
  console.log("========================");
  // admin
  await fetchRoleAccounts(mcb, mcbGranted, "DEFAULT_ADMIN_ROLE", adminRole);
  // sub-roles
  for (var i = 0; i < mcbRoles.length; i++) {
    const roleName = mcbRoles[i];
    const roleValue = ethers.utils.id(roleName);
    await fetchRoleAccounts(mcb, mcbGranted, roleName, roleValue);
  }

  const valueCapture = await deployer.getDeployedContract("ValueCapture");
  const captureNotifyRecipient = await valueCapture.captureNotifyRecipient();

  console.log("Checklist:");
  console.log("========================");
  console.log("  -", passOrWarn("Authenticator.VALUE_CAPTURE_ROLE: <= 1", granted["VALUE_CAPTURE_ROLE"].length <= 1));
  console.log(
    "  -",
    passOrWarn(
      "Authenticator.VALUE_CAPTURE_ROLE: has ValueCapture",
      granted["VALUE_CAPTURE_ROLE"].includes(deployer.addressOf("ValueCapture"))
    )
  );

  console.log("  -", passOrWarn("Authenticator.DEFAULT_ADMIN_ROLE: <= 1", granted["DEFAULT_ADMIN_ROLE"].length <= 1));
  console.log(
    "  -",
    passOrWarn(
      "Authenticator.DEFAULT_ADMIN_ROLE: has ValueCapture",
      granted["DEFAULT_ADMIN_ROLE"].includes(deployer.addressOf("Timelock"))
    )
  );

  console.log(
    "  -",
    passOrWarn("Authenticator.VALUE_CAPTURE_ADMIN_ROLE: <= 1", granted["VALUE_CAPTURE_ADMIN_ROLE"].length <= 1)
  );
  console.log("  -", passOrWarn("Authenticator.XMCB_ADMIN_ROLE: <= 1", granted["XMCB_ADMIN_ROLE"].length <= 1));
  console.log("  -", passOrWarn("Authenticator.MINTER_ADMIN_ROLE: <= 1", granted["MINTER_ADMIN_ROLE"].length <= 1));

  console.log("  -", passOrWarn("MCB.DEFAULT_ADMIN_ROLE: <= 1", mcbGranted["DEFAULT_ADMIN_ROLE"].length <= 1));
  console.log("  -", passOrWarn("MCB.MINTER_ROLE: <= 1", mcbGranted["MINTER_ROLE"].length <= 1));
  console.log(
    "  -",
    passOrWarn("MCB.MINTER_ROLE: has MCBMinter", mcbGranted["MINTER_ROLE"].includes(deployer.addressOf("MCBMinter")))
  );

  console.log(
    "  -",
    passOrWarn(
      "ValueCapture.captureNotifyRecipient: is MCBMinter",
      captureNotifyRecipient == deployer.addressOf("MCBMinter")
    )
  );
}

async function main(deployer, accounts) {
  await verifyArguments(deployer, accounts);
  await verifyRoles(deployer, accounts);
}

ethers
  .getSigners()
  .then((accounts) => readOnlyEnviron(ethers, ENV, main, accounts))
  .then(() => process.exit(0))
  .catch((error) => {
    printError(error);
    process.exit(1);
  });

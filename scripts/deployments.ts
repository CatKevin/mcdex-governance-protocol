const hre = require("hardhat");
const ethers = hre.ethers;

import { sleep, ensureFinished, printInfo, printError } from "./deployer/utils";

export function toWei(n) {
  return ethers.utils.parseEther(n);
}
export function fromWei(n) {
  return ethers.utils.formatEther(n);
}

export async function deploy(deployer, accounts) {
  const owner = accounts[0];

  await deployer.deployOrSkip("ProxyAdmin");
  await deployer.deployAsUpgradeable(
    "Authenticator",
    deployer.addressOf("ProxyAdmin")
  );
  await deployer.deployAsUpgradeable("XMCB", deployer.addressOf("ProxyAdmin"));
  await deployer.deployAsUpgradeable(
    "Timelock",
    deployer.addressOf("ProxyAdmin")
  );
  await deployer.deployAsUpgradeable(
    "FastGovernorAlpha",
    deployer.addressOf("ProxyAdmin")
  );
  await deployer.deployAsUpgradeable("Vault", deployer.addressOf("ProxyAdmin"));
  await deployer.deployAsUpgradeable(
    "ValueCapture",
    deployer.addressOf("ProxyAdmin")
  );
  await deployer.deployAsUpgradeable(
    "RewardDistribution",
    deployer.addressOf("ProxyAdmin")
  );
  await deployer.deployAsUpgradeable(
    "MCBMinter",
    deployer.addressOf("ProxyAdmin")
  );
}

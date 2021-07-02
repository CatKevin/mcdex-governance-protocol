const hre = require("hardhat");
const ethers = hre.ethers;

import { DeploymentOptions } from "./deployer/deployer";
import { restorableEnviron } from "./deployer/environ";
import { printError } from "./deployer/utils";

const ENV: DeploymentOptions = {
  network: hre.network.name,
  artifactDirectory: "./artifacts/contracts",
  addressOverride: {
    // arb-rinkeby
    MCB: "0x4e352cF164E64ADCBad318C3a1e222E9EBa4Ce42",
    MCBVesting: "0x80EefA1DEd44f08e2DaCFab07B612bE66363326e",
    ProxyAdmin: "0x93a9182883C1019e1dBEbB5d40C140e7680cd151",
  },
};

import { deploy } from "./deployments";
import { initialize, startMining } from "./initializations";

async function main(deployer, accounts) {
  // 1. deploy
  // await deploy(deployer, accounts);
  await initialize(deployer, accounts);
  // await startMining(deployer, accounts)
}

ethers
  .getSigners()
  .then((accounts) => restorableEnviron(ethers, ENV, main, accounts))
  .then(() => process.exit(0))
  .catch((error) => {
    printError(error);
    process.exit(1);
  });

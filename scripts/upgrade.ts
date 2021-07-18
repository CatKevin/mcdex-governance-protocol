const hre = require("hardhat");
const ethers = hre.ethers;

import { DeploymentOptions } from "./deployer/deployer";
import { readOnlyEnviron } from "./deployer/environ";
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

async function main(deployer, accounts) {
  //   await deployer.deploy("GovernorAlpha");
  //   Deployer => GovernorAlpha has been deployed to 0xcE7822A60D78Ae685A602985a978dcAdE249b387
  //   const proxyAdmin = await deployer.getDeployedContract("ProxyAdmin");
  //   await proxyAdmin.upgrade("0x8597eB9E005f39f8f70A17aeA914B20450ABfE60", "0xcE7822A60D78Ae685A602985a978dcAdE249b387");
  // const auth = await deployer.getDeployedContract("Authenticator");
  // await auth.grantRole(
  //   "0xe84d166bad4981073f1b4bdc5fecdb216902502bdfea5c01391b14df2724e4f7",
  //   "0x0AA354A392745Bc5f63ff8866261e8B6647002DF"
  // );
  // const vesting = await ethers.getContractAt("Ownable", "0x80EefA1DEd44f08e2DaCFab07B612bE66363326e");
  // console.log(await vesting.owner());
  // await vesting.transferOwnership("0x25c646AdF184051B35A405B9aaEBA321E8d5342a");
  // console.log(await vesting.owner());

  const auth = await deployer.getDeployedContract("Authenticator");
  await auth.renounceRole(
    "0x0000000000000000000000000000000000000000000000000000000000000000",
    "0x904b5993fC92979eeEdC19cCC58bED6B7216667c"
  );
}

ethers
  .getSigners()
  .then((accounts) => readOnlyEnviron(ethers, ENV, main, accounts))
  .then(() => process.exit(0))
  .catch((error) => {
    printError(error);
    process.exit(1);
  });

const yaml = require("js-yaml");
const fs = require("fs");

import { getStorageLayout } from "./layout";
import { printInfo, printError, getCurrentBranch, getCurrentCommitShort } from "./utils";

const PREFIX = "./storagelayouts";

async function main() {
  const branch = getCurrentBranch();
  const commitHash = getCurrentCommitShort();
  printInfo(`Working on ${branch} with commit ${commitHash}`);

  const target = yaml.load(fs.readFileSync("./scripts/upgrade/target.yml", "utf8"));
  const outDir = `${PREFIX}/${branch}`;
  const outPath = `${outDir}/${commitHash}.yml`;
  fs.mkdirSync(outDir, { recursive: true });

  const layouts = {};
  for (var i = 0; i < target.contracts.length; i++) {
    const path = target.contracts[i];
    printInfo(`begin processing ${path}.`);
    const layout = await getStorageLayout(path);
    layouts[path] = layout;
    printInfo(`processing ${path} done.`);
  }

  fs.writeFileSync(outPath, yaml.dump(layouts));
  printInfo(`layouts has been written to ${outPath}. ${target.contracts.length} contracts generated.`);

  // const path = "contracts/upgrade/UpgradeMulti.sol";
  // const name = "UpgradeV3";
  // const layoutBefore = await getStorageLayout("contracts/upgrade/UpgradeCase.sol", "UpgradeBefore");
  // const layoutAfter = await getStorageLayout("contracts/upgrade/UpgradeCase.sol", "UpgradeAfter");
  // printLayout(layoutBefore, "BEFORE");
  // console.log("");
  // printLayout(layoutAfter, "AFTER");
  // console.log("");
  // compareLayout(layoutBefore, layoutAfter);
}

main().then().catch(printError);

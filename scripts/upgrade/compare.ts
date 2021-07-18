import { artifacts } from "hardhat";
const chalk = require("chalk");

import { getStorageLayout } from "./layout";

export function printInfo(...message) {
  console.log(chalk.yellow("INFO "), ...message);
}
export function printError(...message) {
  console.log(chalk.red("ERRO "), ...message);
}

function printLayout(layout, title = "ROOT") {
  const _printLayout = (layout, indent) => {
    for (var i = 0; i < layout.length; i++) {
      const node = layout[i];
      const padding = " ".repeat(indent) + (indent == 0 ? "" : "- ");
      console.log(`${padding}${chalk.yellow(node.name)} [${node.id}][${chalk.magentaBright(node.typeName)}]`);
      if ("subType" in node) {
        _printLayout(node.subType, indent + 2);
      }
    }
  };
  console.log(title);
  _printLayout(layout, 0);
}

function compareLayout(layoutBeforeUpgrade, layoutAfterUpgrade) {
  const _compareLayout = (before, after) => {
    for (var i = 0; i < before.length; i++) {
      const nodeBefore = before[i];
      const nodeAfter = after[i];

      assert(
        nodeBefore.typeName == nodeAfter.typeName,
        `DEFINE_ERROR: var [${nodeBefore.name}], ${nodeBefore.typeName} => ${nodeAfter.typeName}`
      );
      assert(
        !("keyType" in nodeBefore) || nodeBefore.keyType == nodeAfter.keyType,
        `KEY_TYPE_ERROR: var [${nodeBefore.name}], ${nodeBefore.typeName} => ${nodeAfter.typeName}`
      );
      // optional
      assert(
        !("length" in nodeBefore) || nodeBefore.length == nodeAfter.length,
        `LENGTH_ERROR: var [${nodeBefore.name}], ${nodeBefore.length} => ${nodeAfter.length}`
      );
    }
  };
  try {
    _compareLayout(layoutBeforeUpgrade, layoutAfterUpgrade);
  } catch (e) {
    printError(e);
  }
}

function assert(condition, message) {
  if (!condition) {
    throw message;
  }
}

async function main() {
  const path = "contracts/upgrade/UpgradeMulti.sol";
  const name = "UpgradeV3";
  const layoutBefore = await getStorageLayout("contracts/upgrade/UpgradeCase.sol:UpgradeBefore");
  const layoutAfter = await getStorageLayout("contracts/upgrade/UpgradeCase.sol:UpgradeAfter");
  printLayout(layoutBefore, "BEFORE");
  console.log("");
  printLayout(layoutAfter, "AFTER");
  console.log("");
  compareLayout(layoutBefore, layoutAfter);
}

main().then().catch(printError);

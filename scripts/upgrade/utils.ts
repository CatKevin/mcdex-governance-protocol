const chalk = require("chalk");
const { execSync } = require("child_process");

export function getCurrentBranch() {
  const stdout = execSync("git rev-parse --abbrev-ref HEAD");
  return stdout.toString().trim();
}

export function getCurrentCommitShort() {
  const stdout = execSync("git rev-parse --short HEAD");
  return stdout.toString().trim();
}

export function printInfo(...message) {
  console.log(chalk.yellow("INFO "), ...message);
}

export function printError(...message) {
  console.log(chalk.red("ERRO "), ...message);
}

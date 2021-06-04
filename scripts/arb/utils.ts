const ethers = require("ethers")
const chalk = require('chalk')

export function printInfo(...message) {
    console.log(chalk.yellow("INFO "), ...message)
}
export function printError(...message) {
    console.log(chalk.red("ERRO "), ...message)
}
export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }
export function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

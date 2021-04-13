const { ethers } = require("hardhat");

export function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

export function toWei(n) { return ethers.utils.parseEther(n) };
export function fromWei(n) { return ethers.utils.formatEther(n); }



export async function ensureFinished(transation): Promise<any> {
    const result = await transation;
    if (typeof result.deployTransaction != 'undefined') {
        await result.deployTransaction.wait()
    } else {
        await result.wait()
    }
    return result
}

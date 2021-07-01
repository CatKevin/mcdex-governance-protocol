const { ethers } = require("hardhat");

export class Deployer {
    public deployedContracts = {};

    public async getFactory(contractName: string): Promise<any> {
        return await ethers.getContractFactory(contractName);
    }

    public async deploy(contractName: string, ...args): Promise<any> {
        const factory = await this.getFactory(contractName);
        const deployed = await factory.deploy(...args);
        this.deployedContracts[contractName] = { address: deployed.address };
        return deployed;
    }

    public async deployWith(
        signer: any,
        contractName: string,
        ...args
    ): Promise<any> {
        return await this.deploy(contractName, ...args);
    }

    public async deployOrSkip(contractName: string, ...args): Promise<any> {
        if (contractName in this.deployedContracts) {
            return this.getDeployedContract(contractName);
        }
        return await this.deploy(contractName, ...args);
    }

    public async deployAsUpgradeable(
        contractName: string,
        admin: string
    ): Promise<any> {
        return await this.deploy(contractName);
    }

    public async getDeployedContract(contractName: string): Promise<any> {
        if (!(contractName in this.deployedContracts)) {
            throw `${contractName} has not yet been deployed`;
        }
        const factory = await this.getFactory(contractName);
        return await factory.attach(this.deployedContracts[contractName].address);
    }
}

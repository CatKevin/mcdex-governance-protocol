# MCDEX DAO

The MCDEX community has issued its governance token MCB and has done a series of governance work. While launching the Mai3 protocol, we will establish MCDEX DAO based on MCB. MCDEX DAO will be the core of the MCDEX community. The mission of MCDAO is to continuously develop the MCDEX ecosystem.

Check [References](https://mcdex.io/references/#/en-US/mcdex-dao) for more information about MCDEX DAO.

Check [README.md](./docs/README.md) for more information about the code structure.

## Audit

The smart contracts were audited by CertiK: [MCDEX DAO Audit Report](https://mcdexio.github.io/documents/en/CertiK-Audit-Report-for-MCDEX-DAO-final.pdf).

## Deployed Contracts


### Arbitrum One Mainnet

|Contract|Description|Address|
|---|---|---|
|[`Authenticator (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to Authenticator. |[0x54752977A387a2eABdce47e575940d15BCc319c5](https://explorer.offchainlabs.com/address/0x54752977A387a2eABdce47e575940d15BCc319c5)|
|[`Authenticator (implementation)`](contracts/Authenticator.sol) |It is the central permission management module of all the DAO contracts. |[0x737Da8533E4fA59C1292545d8D155c199567AcF2](https://explorer.offchainlabs.com/address/0x737Da8533E4fA59C1292545d8D155c199567AcF2)|
|[`XMCB (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to XMCB. |[0x1284c70F0ed8539F450584Ce937267F8C088B4cC](https://explorer.offchainlabs.com/address/0x1284c70F0ed8539F450584Ce937267F8C088B4cC)|
|[`XMCB (implementation)`](contracts/XMCB.sol) |A delegateable ERC20 token with snapshot mechanism applied on account balance, mainly used as a proof of MCB staking. |[0x369878Ecc69B7148b7cC151d1a03dbcbfD9b537E](https://explorer.offchainlabs.com/address/0x369878Ecc69B7148b7cC151d1a03dbcbfD9b537E)|
|[`Timelock (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to Timelock. |[0x1284c70F0ed8539F450584Ce937267F8C088B4cC](https://explorer.offchainlabs.com/address/0x1284c70F0ed8539F450584Ce937267F8C088B4cC)|
|[`Timelock (implementation)`](contracts/Timelock.sol) |A delayed executor. |[0xdE62adA1C78fDC8Bfa62c7945Fdd0Fa1F8be2233](https://explorer.offchainlabs.com/address/0xdE62adA1C78fDC8Bfa62c7945Fdd0Fa1F8be2233)|
|[`GovernorAlpha (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to GovernorAlpha. |[0x1284c70F0ed8539F450584Ce937267F8C088B4cC](https://explorer.offchainlabs.com/address/0x1284c70F0ed8539F450584Ce937267F8C088B4cC)|
|[`GovernorAlpha (implementation)`](contracts/GovernorAlpha.sol) |Voting. |[0xcE7822A60D78Ae685A602985a978dcAdE249b387](https://explorer.offchainlabs.com/address/0xcE7822A60D78Ae685A602985a978dcAdE249b387)|
|[`Vault (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to Vault. |[0xD78ba1D99dbBC4ebA3B206c9C67a08879b6eC79B](https://explorer.offchainlabs.com/address/0xD78ba1D99dbBC4ebA3B206c9C67a08879b6eC79B)|
|[`Vault (implementation)`](contracts/Vault.sol) |Store assets owned by the DAO. |[0xc344191DC17b0e1a5D50448662105eD590681503](https://explorer.offchainlabs.com/address/0xc344191DC17b0e1a5D50448662105eD590681503)|
|[`ValueCapture (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to ValueCapture. |[0xa04197E5F7971E7AEf78Cf5Ad2bC65aaC1a967Aa](https://explorer.offchainlabs.com/address/0xa04197E5F7971E7AEf78Cf5Ad2bC65aaC1a967Aa)|
|[`ValueCapture (implementation)`](contracts/ValueCapture.sol) |Receives fee from pools (`LiquidityPool`) and count the total value received in USD. |[0x5FCDfD5634c50CCcEf6275a239207B09Bd0379df](https://explorer.offchainlabs.com/address/0x5FCDfD5634c50CCcEf6275a239207B09Bd0379df)|
|[`RewardDistribution (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to RewardDistribution. |[0x694baa24d46530E46BCd39b1F07943a2BDDb01e6](https://explorer.offchainlabs.com/address/0x694baa24d46530E46BCd39b1F07943a2BDDb01e6)|
|[`RewardDistribution (implementation)`](contracts/components/staking/RewardDistribution.sol) |The algorithm to distribute captured value. |[0xcC8A884396a7B3a6e61591D5f8949076Ed0c7353](https://explorer.offchainlabs.com/address/0xcC8A884396a7B3a6e61591D5f8949076Ed0c7353)|
|[`MCBMinter (proxy)`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.4.0/contracts/proxy/TransparentUpgradeableProxy.sol) |A proxy to MCBMinter. |[0x7230D622D067D9C30154a750dBd29C035bA7605a](https://explorer.offchainlabs.com/address/0x7230D622D067D9C30154a750dBd29C035bA7605a)|
|[`MCBMinter (implementation)`](contracts/minter/MCBMinter.sol) |Minter of MCB. |[0xbe7Bd523Fb0A1E397bfb109D4306cd421d58b560](https://explorer.offchainlabs.com/address/0xbe7Bd523Fb0A1E397bfb109D4306cd421d58b560)|


## test && coverage

```shell
// run test
npx hardhat test

// run coverage
npx hardhat coverage
```


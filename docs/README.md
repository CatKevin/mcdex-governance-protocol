# MCDEX DAO

[TOC]



## Overview

![image-20210329215643533](../misc/overview.png)









## Contracts on Layer-1

### Minter

`Minter` system is designed to take over the role of MCB minter.

A generic description to the rule of MCB release is:

- `ValueCapture` receives fees from `LiquidityPool`s created by MCDEX v3;
- All the token collected by `ValueCapture` will be sold for USD token, then update the captured value in USD and forward to the `Vault`;
- `Minter` read the captured value in USD and mint new MCB, one MCB per captured USD token. The captured value are minted into two parts:
  - Base part. This part is the funds for DAO activates like mining or reward to MCB holders. The base part is controlled by MCB holder through a voting governance system. Every proposal to mint from the base part must win a vote before applied.
  - Series-A part. This part belongs to the vesting of token sales. The minted MCB will be transferred to a immutable adress which is a vesting contract and the investors can later withdraw the tokens by themself. This part has a higher priority than the base part and do not need to vote to mint.

The rule of releasing can be found on [MCB Tokenomics (mcdex.io)](https://v3.mcdex.io/references/#/en-US/mcb-tokenomics).

And there is also some assumptions for the minting progress:

- The minting request must be initiated from L2.

- By default, new MCB should be minted to an L2 address.

Since the main components including the `ValueCapture` contract are deployed on L2 network and the `Mint` contract is deployed on L1 network, there are some helper contracts to help `Minter` contract get the correct captured value and send minted token to L2.

![Mint To L2](../misc/minttol2.png)

The sequence chart shows how the MCB token are minted to a L2 receiver.

For more technical details, check [Arbitrum](https://developer.offchainlabs.com/docs/developer_quickstart).

#### Methods

```javascript
function getSeriesAMintableAmount() public returns (uint256)
function getBaseMintableAmount() public returns (uint256)
```

Call these method to retrieve current mintable amount of base part and series-A part.

*Before read the amounts, a update operation will be performed, so the methods are not read-only. Try use staticCall to get the result.*

```javascript
function receiveBaseMintRequestFromL2(
	uint8 releaseType,
	address recipient,
	uint256 amount
) public
function executeBaseMintRequest(
	uint256 index,
    address bridge,
    uint256 maxSubmissionCost,
    uint256 maxGas,
    uint256 gasPriceBid
) public
```

`receiveBaseMintRequestFromL2` receives requests from L2 and can be executed through `executeBaseMintRequest`.

The usage of auguments `bridge`, `maxSubmissionCost`, `maxGas` and `gasPriceBid` can be found in  [Arbitrum](https://developer.offchainlabs.com/docs/developer_quickstart).

```javascript
function seriesAMint(
	uint256 amount,
	address bridge,
	uint256 maxSubmissionCost,
	uint256 maxGas,
	uint256 gasPriceBid
) public
```

Any one is able to call `seriesAMint` before reach the mintable limitation.

#### Actors

- **DAO** controls when to mint new MCB;
- **DevTeam** receives a share from the minted MCB; The dev team is able to transfer the beneficial account to another.
- **DataExchage** supplies the total captured value in USD.
- **MintInitiator** sends request for DAO from L2 to `Minter`.
- **ERC20Bridge** helpes to transfer ERC20 token (MCB) across L1 and L2.



## Contracts on Layer-2

### Authentication

#### Overview

Authentication is basically the `AccessControl` contract implemented by `OpenZepplin`.It is the central permission management module of all the DAO contracts. Every authentication request is sent to this contract, then been test if an account has granted specific role to call specific function.

The `DEFAULT_ADMIN_ROLE` (0x0) role will be set to contract deployer to help to initialize the trust chain of the DAO system and finally will be set to `Timelock` contract after all initialization finished.

#### Methods

```javascript
function hasRoleOrAdmin(bytes32 role, address account) external view returns (bool)
```

External contracts to check authority should call this method to get whether an account has the permission. For other methods, check [openzeppelin-contracts-upgradeable/AccessControlUpgradeable.sol](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/release-v3.4/contracts/access/AccessControlUpgradeable.sol) for details

#### Roles

In DAO system, roles are represented by a bytes32 which is calculated from the string value of the role itself. For example, the value of `DEFAULT_ADMIN_ROLE` can be retrieved from `keccak256("DEFAULT_ADMIN_ROLE")`.

The `DEFAULT_ADMIN_ROLE` is not only the controller of the authentication module, but also the 'role admin' of all sub-roles. That means only the `DEFAULT_ADMIN_ROLE` can grant or revoke method to change the role of an account.

*By design, `DEFAULT_ADMIN_ROLE` is able to perform all actions that only available to the sub-roles. If not stated, all role designs should follow this rule.*



### Vault

#### Overview

Vault contract is used to store assets owned by the DAO. It has some transfer methods to helper call to transfer stored assets to destination. The deployed vault contract is controlled by `Timelock` contract which means every transfer will be and only can be initiated by governance proposal.

#### Methods

There are 3 transfer function to help caller to transfer assets to some where.

```javascript
function transferETH(address recipient, uint256 value) external onlyAuthorized

function transferERC20(
	address token,
	address recipient,
	uint256 amount
) external onlyAuthorized

function transferERC721(
	address token,
	uint256 tokenID,
	address recipient
) external onlyAuthorized
```

For an unsupported token, the transfer is able to be achieved though `execute`:

```javascript
function execute(
	address to,
	bytes calldata data,
	uint256 value
) external onlyAuthorized
```

All the methods above require authentication to be called.

#### Roles

`VAULT_ADMIN_ROLE` is a reserved role who is able to call the transfer methods. It will be left unset before encountering special needs. So the vault should be actually controlled by  the `Timelock` contract only.



### ValueCapture

#### Overview

The ValueCapture contract is mainly to receives fee from pools (`LiquidityPool`) and count the total value received in USD. The captured value is related to the MCB releasing model, see [whitepaper]() for details.

Since the fee tokens collected are various, the ValueCapture relies on external exchanges to convert various tokens into whitelisted USD token (eg. USDT, USDC and so on).

Also, for tokens that has no liquidity, the admin can directly forward them to vault without conversion. Token forwarded through this way will not be counted into captured value.

![forward asset](../misc/valuecapture_seq.png)

This chart shows how the ValueCapture capture and count fee collected from liquidity pools.

#### Methods

```javascript
function addUSDToken(address token, uint256 decimals) public onlyAuthorized

function removeUSDToken(address token) public onlyAuthorized
```

These two method is used to maintain the USD whitelist.

```javascript
function setConvertor(
	address token,
	address oracle,
	address convertor_,
	uint256 slippageTolerance
) public onlyAuthorized
```

The admin can set a convertor for a token. Besides the convertor contract, the admin should also supply a oracle to determine the market price of the token being converted. And the slippage tolerance defines the max price loss  [`(dealPrice - marketPrice) / marketPrice`] in a conversion.

```javascript
function forwardAsset(address token) public onlyAuthorized
```

Convert token into whitelisted USD.

Any one is able to call this method but should make sure the slippage of price within the range set by admin, or the transaction will be reverted.

```javascript
function forwardETH(uint256 amount) public

function forwardERC20Token(address token, uint256 amount) public onlyAuthorized

function forwardERC721Token(address token, uint256 tokenID) public onlyAuthorized
```

Directly transfer asset to vault. All the transferred value will not be counted into the captured value.

#### Roles

- **`VALUE_CAPTURE_ADMIN_ROLE`** is able to:
  - maintains USD whitelist;
  - maintain convertors;
  - forward asset directly to vault.

Calling `forwardAsset` does not need special permission.



### XMCB

#### Overview

XMCB is implemented based on `Comp` token crafted by Compound. It is a delegateable ERC20 token with snapshot mechanism applied on account balance, mainly used as a proof of MCB staking.

User can deposit and withdraw MCB for XMCB at any time. There no lock on withdrawal but user has to afford a penalty (defined by `withdrawalPenaltyRate`, usually 5%) on withdrawal MCB. The penalty will be shared by all the remaining XMCB holders.

Another usage of XMCB is to broadcast deposit / withdraw calls to all registered components. A component is a external contract that depends on user XMCB deposited balance to achieve various activities, say, mining.

Following methods are disabled in `XMCB` because it is a non-transferrable token:

- transfer
- transferFrom
- allowance
- approve

#### Methods

```javascript
function setWithdrawalPenaltyRate(uint256 withdrawalPenaltyRate_) public onlyAuthorized
```

The admin is able to set withdrawal penalty. New penalty will only applied to transactions after penalty rate changed. The rate shall not exceed 100%.

```javascript
function deposit(uint256 amount) public

function withdraw(uint256 amount) public
```

As mentioned above, user deposits MCB into contract will always receive the same amount of XMCB. User always loses a percentage of withdrawal amount when withdraws MCB from XMCB.

The last withdrawal which makes the deposited balance to 0 will ignore the penalty. User will get all his remaining balance.

For example, assuming the penalty rate is 5%:

- Bob deposits 100 MCB and gets 100 XMCB back;
- Alice deposits 100 MCB and gets 100 XMCB back;
- Alice try to withdraws 100 MCB with 100 XMCB and gets 95 MCB back;
- Now Bob has 105 XMCB;
  - If there is no other user, Bob is able to withdraw 105 MCB with 105 XMCB.
  - If there is other user, Bob is able to withdraw 99.75 MCB with 105 XMCB.


```javascript
function addComponent(address component) public onlyAuthorized

function removeComponent(address component) public onlyAuthorized
```

Management interfaces to add component to XMCB or remove component from XMCB.

```javascript
function delegate(address) public

function delegateBySig(address,uint256,uint256,uint8,bytes32,bytes32) public
```

XMCB holder can delegate the 'vote power' to another one. By default, the delegate of user is himself.

#### Roles

- **`XMCB_ADMIN_ROLE`** is able to set the value of `withdrawPenaltyRate`.
- **User**  is able to stake MCB into XMCB for reward and vote.



### DataExchange

`DataExchange` is a key-value storage system for sharing data between L1 and L2 network. It is not designed to be a generic exchange and only promises eventual consistency.

The main feature of `DataExchange` contract are:

- Only authorized account is able to push data to `DataExchange`.

- Data sync is asynchronous and must be triggered by a keeper, so the arrive time is unpredictable.
- Data with the same key before recorded latest timestamp will be discard.

### Methods

```javascript
function getData(bytes32 key) public view returns (bytes memory, bool)
```

Retreive data in bytes format and if the data exists. Retreiver need to decode to get the raw data. For example:

```solidity
// to get a store tuple (uint256 value1, uint256 value2) with key DATA_KEY
(bytes memory data, bool exist) = dataExchange.getData(DATA_KEY);
require(exist, "data for key is not exist");
(uint256 value1, uint256 value2) = abi.decode(data, (uint256, uint256));
```

```javascript
function feedDataFromL1(
	bytes32 key,
	bytes calldata data,
	address inbox,
	uint256 maxGas,
	uint256 gasPriceBid
) public onlyL1

function tryFeedDataFromL1(
	bytes32 key,
	bytes calldata data,
 	address inbox,
 	uint256 maxGas,
 	uint256 gasPriceBid
) public onlyL1
```

Send data from L1 to L2.

```javascript
function feedDataFromL2(bytes32 key, bytes calldata data) public onlyL2

function tryFeedDataFromL2(bytes32 key, bytes calldata data) public onlyL2
```

Send data from L2 to L1.

The method with prefix 'try' will not revert on error.

#### Roles

- **`DATA_EXCHANGE_ADMIN_ROLE`** is able to assign source for a data key.

- **L2 User** can send data to L2 to L1.

- **L1 User** can send data from L1 to L2.



### GovernorAlpha && Timelock

GovernorAlpha and Timelock are also created based on the contracts with the same names from Compound. Most of their functions are just left unchanged.  The GovernorAlpha takes the XMCB token as its voting token.

#### GovernorAlpha

Changes:

- Code updates according to new solidity compiler version (0.7.4);

- The values of `quorumVotes` and `proposalThreshold`  now use the dynamic amount based on current `totalSupply` of MCB on creating proposal, instead of two fixed amounts.
- Retrieve total supply of MCB from `DataExchange`.

#### Timelock

Changes:

- Code updates according to new solidity compiler version (0.7.4);





### MintInitiator

The `MintInitiator` contract is deployed on L2 network and only trusts admin of DAO.

When a MCB minting proposal succeeded, the execution will fire a transaction from `MintInitiator `, send a request to L1 then wait for the request appearing on the L1 network. The request finally can be executed by anyone on L1 to complete the minting process.

#### Methods

```javascript
function sendMintRequest(
	uint8 releaseType,
	address recipient,
	uint256 amount
) public onlyAuthorized
```

The `releaseType` indicates which network the recipient is on. The options are `None`, `ToL1` and `ToL2`.

#### Roles

- **`DEFAULT_ADMIN_ROLE`** is able to send minting request.



## Appendix

### I. Parameters of Governor

| Name                  | Value                     | Note                                    |
| --------------------- | ------------------------- | --------------------------------------- |
| quorumVotes           | 10% * total supply of MCB | minimal for votes for a proposal to win |
| proposalThreshold     | 1%  * total supply of MCB | minimal votes to create proposal        |
| proposalMaxOperations | 10                        | max operations in one proposal          |
| votingDelay           | 1 block                   |                                         |
| votingPeriod          | 17280 block               | about 3 days                            |
| timelock delay        | 2 day                     |                                         |


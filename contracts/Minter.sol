// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "hardhat/console.sol";

interface IValueCapture {
    function totalCapturedUSD() external view returns (uint256);
}

interface IMCB is IERC20Upgradeable {
    function mint(address account, uint256 amount) external;
}

contract Minter {
    using AddressUpgradeable for address;

    using MathUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;

    uint256 public constant TOTAL_SUPPLY = 10000000 * 1e18; // 10,000,000
    uint256 public constant DEV_COMMISSION_RATE = 25 * 1e16; // 25%
    uint256 public constant GENESIS_BLOCK = 0;

    struct Release {
        address recipient;
        uint256 releaseRate;
        uint256 mintableAmount;
        uint256 mintedAmount;
        uint256 maxSupply;
        uint256 lastCapturedBlock;
    }

    IMCB public mcbToken;
    IValueCapture public valueCapture;

    address public devAccount;
    uint256 public lastCaptureValue;
    uint256 public extraMintableAmount;
    uint256 public totalCapturedValue;

    Release public toVault;
    Release public toSeriesA;

    event MintMCB(
        address indexed recipient,
        uint256 amount,
        uint256 recipientReceivedAmount,
        uint256 devReceivedAmount
    );

    event SetDevAccount(address indexed devOld, address indexed devNew);

    constructor(
        address mcbToken_,
        address valueCapture_,
        address devAccount_,
        Release memory toVault_,
        Release memory toSeriesA_
    ) {
        require(mcbToken_.isContract(), "token must be contract");
        require(valueCapture_.isContract(), "value capture must be contract");
        mcbToken = IMCB(mcbToken_);
        valueCapture = IValueCapture(valueCapture_);

        devAccount = devAccount_;

        toVault = toVault_;
        toVault.lastCapturedBlock = GENESIS_BLOCK;
        toSeriesA = toSeriesA_;
        toSeriesA.lastCapturedBlock = GENESIS_BLOCK;
    }

    function setDevAccount(address devAccount_) external {
        require(msg.sender == devAccount, "caller must be dev account");
        require(devAccount_ != devAccount, "already dev account");
        emit SetDevAccount(devAccount, devAccount_);
        devAccount = devAccount_;
    }

    function getMintableAmountToSeriesA() public returns (uint256) {
        updateMintableAmount();
        return toSeriesA.mintableAmount;
    }

    function getMintableAmountToVault() public returns (uint256) {
        updateMintableAmount();
        return toVault.mintableAmount;
    }

    function mintToSeriesA(uint256 amount) public {
        _mint(toSeriesA, amount);
    }

    function mintToVault(uint256 amount) public {
        _mint(toVault, amount);
    }

    function _mint(Release storage release, uint256 amount) internal {
        require(amount > 0, "amount is zero");

        updateMintableAmount();
        require(amount <= release.mintableAmount, "amount exceeds mintable");

        uint256 toDevAmount = amount.mul(DEV_COMMISSION_RATE).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(devAccount, toDevAmount);
        mcbToken.mint(release.recipient, toRecipientAmount);
        release.mintableAmount = release.mintableAmount.sub(amount);
        release.mintedAmount = release.mintedAmount.add(amount);

        require(release.mintedAmount <= release.maxSupply, "minted exceeds release supply");
        require(mcbToken.totalSupply() <= TOTAL_SUPPLY, "minted exceeds total supply");

        emit MintMCB(release.recipient, amount, toRecipientAmount, toDevAmount);
    }

    function updateSeriesAMintableAmount() internal {
        if (_getBlockNumber() <= toSeriesA.lastCapturedBlock || extraMintableAmount == 0) {
            return;
        }
        uint256 remainSupply =
            toSeriesA.maxSupply.sub(toSeriesA.mintedAmount).sub(toSeriesA.mintableAmount);
        if (remainSupply == 0) {
            return;
        }
        uint256 elapsedBlock = _getBlockNumber().sub(toSeriesA.lastCapturedBlock);
        uint256 mintableAmountToSeriesA =
            elapsedBlock.mul(toSeriesA.releaseRate).min(extraMintableAmount).min(remainSupply);
        // **TO SERIES A**: extra
        toSeriesA.mintableAmount = toSeriesA.mintableAmount.add(mintableAmountToSeriesA);
        extraMintableAmount = extraMintableAmount.sub(mintableAmountToSeriesA);
        toSeriesA.lastCapturedBlock = _getBlockNumber();
    }

    function updateVaultMintableAmount() internal {
        if (_getBlockNumber() > toVault.lastCapturedBlock) {
            return;
        }
        uint256 capturedValue = valueCapture.totalCapturedUSD();
        uint256 incrementalCapturedValue = capturedValue.sub(totalCapturedValue);
        uint256 elapsedBlock = _getBlockNumber().sub(toVault.lastCapturedBlock);
        uint256 minMintableAmount = elapsedBlock.mul(toVault.releaseRate); // **NOT** 1e18 mul
        if (incrementalCapturedValue > minMintableAmount) {
            extraMintableAmount = incrementalCapturedValue.sub(minMintableAmount);
        }
        toVault.lastCapturedBlock = _getBlockNumber();
        totalCapturedValue = capturedValue;
    }

    function updateMintableAmount() internal {
        updateVaultMintableAmount();
        updateSeriesAMintableAmount();
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}

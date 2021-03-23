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

    uint256 public constant MAX_TOTAL_SUPPLY = 10000000 * 1e18;

    struct Release {
        address recipient;
        uint256 releaseRate;
        uint256 mintableAmount;
        uint256 mintedAmount;
        uint256 totalSupply;
    }

    IMCB public mcbToken;
    IValueCapture public valueCapture;

    address public devAccount;
    uint256 public devShareRate;
    uint256 public genesisBlock;
    uint256 public lastCaptureValue;
    uint256 public lastCaptureBlock;
    uint256 public cumulativeCapturedValue;

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
        uint256 devShareRate_,
        uint256 genesisBlock_,
        Release memory toVault_,
        Release memory toSeriesA_
    ) {
        require(mcbToken_.isContract(), "token must be contract");
        require(valueCapture_.isContract(), "value capture must be contract");
        mcbToken = IMCB(mcbToken_);
        valueCapture = IValueCapture(valueCapture_);

        devAccount = devAccount_;
        devShareRate = devShareRate_;
        genesisBlock = genesisBlock_;
        lastCaptureBlock = genesisBlock_;
        toVault = toVault_;
        toSeriesA = toSeriesA_;
    }

    function setDevAccount(address devAccount_) external {
        require(msg.sender == devAccount, "caller must be dev account");
        require(devAccount_ != devAccount, "already dev account");
        emit SetDevAccount(devAccount, devAccount_);
        devAccount = devAccount_;
    }

    function getMintableAmountToSeriesA() public returns (uint256) {
        _updateCapturedValue();
        return toSeriesA.mintableAmount;
    }

    function getMintableAmountToVault() public returns (uint256) {
        _updateCapturedValue();
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

        _updateCapturedValue();
        require(amount <= release.mintableAmount, "amount exceeds mintable");

        uint256 toDevAmount = amount.mul(devShareRate).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(devAccount, toDevAmount);
        mcbToken.mint(release.recipient, toRecipientAmount);
        release.mintableAmount = release.mintableAmount.sub(amount);
        release.mintedAmount = release.mintedAmount.add(amount);
        require(release.mintedAmount <= release.totalSupply, "minted exceeds release supply");
        require(mcbToken.totalSupply() <= MAX_TOTAL_SUPPLY, "minted exceeds total supply");

        emit MintMCB(release.recipient, amount, toRecipientAmount, toDevAmount);
    }

    function _updateCapturedValue() internal {
        uint256 capturedValue = valueCapture.totalCapturedUSD();
        uint256 incrementalCapturedValue = capturedValue.sub(lastCaptureValue);
        _updateMintableAmount(incrementalCapturedValue);
        lastCaptureValue = capturedValue;
    }

    function _updateMintableAmount(uint256 capturedValue) internal {
        console.log("[DEBUG] capturedValue", capturedValue);

        if (_getBlockNumber() <= lastCaptureBlock) {
            return;
        }
        uint256 elapsedBlock = _getBlockNumber().sub(lastCaptureBlock);
        uint256 minMintableAmount = elapsedBlock.mul(toVault.releaseRate); // **NOT** 1e18 mul
        uint256 extraMintableAmount = 0;

        console.log("[DEBUG] elapsedBlock", elapsedBlock);
        console.log("[DEBUG] minMintableAmount", minMintableAmount);
        // if any extra mintable amount
        if (capturedValue > minMintableAmount) {
            // minted + mintable <= totalSupply
            uint256 remainSupply =
                toSeriesA.totalSupply.sub(toSeriesA.mintedAmount).sub(toSeriesA.mintableAmount);
            if (remainSupply > 0) {
                // increase series A mintable amount, if captured value is greater than reserved value
                extraMintableAmount = capturedValue.sub(minMintableAmount);
                uint256 mintableAmountToSeriesA =
                    elapsedBlock.mul(toSeriesA.releaseRate).min(extraMintableAmount).min(
                        remainSupply
                    );
                // **TO SERIES A**: extra
                toSeriesA.mintableAmount = toSeriesA.mintableAmount.add(mintableAmountToSeriesA);
                extraMintableAmount = extraMintableAmount.sub(mintableAmountToSeriesA);
            }
        }
        // **TO DEFAULT**: min mintable + extra mintable
        toVault.mintableAmount = toVault.mintableAmount.add(minMintableAmount).add(
            extraMintableAmount
        );
        // save state
        cumulativeCapturedValue = cumulativeCapturedValue.add(capturedValue);
        lastCaptureBlock = _getBlockNumber();
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}

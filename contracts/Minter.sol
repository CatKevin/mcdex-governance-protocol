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

interface L2Caller {
    function l2Sender() public view returns (address);
}

contract Minter {
    using AddressUpgradeable for address;
    using MathUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;

    enum ReleaseType { NoneType, ReleaseToL1, ReleaseToArbL2 }

    struct ReleaseReceipt {
        ReleaseType releaseType;
        bool executed;
        address recipient;
        uint256 amount;
    }

    address public devAccount;
    address public seriesA;

    uint256 public totalCapturedValue;
    uint256 public lastValueCapturedBlock;

    uint256 public baseMaxSupply;
    uint256 public baseMintedAmount;
    uint256 public baseMinReleaseRate;
    uint256 public extraMintableAmount;

    uint256 public seriesAMaxSupply;
    uint256 public seriesAMintableAmount;
    uint256 public seriesAMintedAmount;
    uint256 public seriesAMaxReleaseRate;
    uint256 public seriesALastUpdateBlock;

    IMCB public mcbToken;
    IValueCapture public valueCapture;
    ReleaseReceipt[] public releaseReceipts;

    event MintMCB(
        address indexed recipient,
        uint256 recipientReceivedAmount,
        address indexed devAccount,
        uint256 devReceivedAmount
    );
    event SetDevAccount(address indexed devOld, address indexed devNew);
    event RequestFromL2();

    constructor(
        address mcbToken_,
        address valueCapture_,
        address seriesA_,
        address devAccount_,
        uint256 baseMaxSupply_,
        uint256 seriesAMaxSupply_,
        uint256 baseMinReleaseRate_,
        uint256 seriesAMaxReleaseRate_
    ) {
        require(mcbToken_.isContract(), "token must be contract");
        require(valueCapture_.isContract(), "value capture must be contract");

        mcbToken = IMCB(mcbToken_);
        valueCapture = IValueCapture(valueCapture_);
        seriesA = seriesA_;
        devAccount = devAccount_;
        require(
            baseMaxSupply_.add(seriesAMaxSupply_).add(mcbToken.totalSupply()) <= mcbTotalSupply(),
            "base + series-a exceeds total supply"
        );
        baseMaxSupply = baseMaxSupply_;
        seriesAMaxSupply = seriesAMaxSupply_;
        baseMinReleaseRate = baseMinReleaseRate_;
        seriesAMaxReleaseRate = seriesAMaxReleaseRate_;
    }

    function genesisBlock() public pure virtual returns (uint256) {
        return 0;
    }

    function mcbTotalSupply() public pure virtual returns (uint256) {
        return 10000000 * 1e18; // 10,000,000
    }

    function devCommissionRate() public pure virtual returns (uint256) {
        return 25 * 1e16; // 25%
    }

    function setDevAccount(address devAccount_) external {
        require(msg.sender == devAccount, "caller must be dev account");
        require(devAccount_ != devAccount, "already dev account");
        emit SetDevAccount(devAccount, devAccount_);
        devAccount = devAccount_;
    }

    function getSeriesAMintableAmount() public returns (uint256) {
        updateMintableAmount();
        return seriesAMintableAmount.min(seriesAMaxSupply);
    }

    function getBaseMintableAmount() public returns (uint256) {
        updateMintableAmount();
        return _getBaseMintableAmount().min(baseMaxSupply);
    }

    function seriesAMint(uint256 amount) public {
        updateMintableAmount();
        require(amount <= _getBaseMintableAmount(), "amount exceeds max mintable amount");
        _mint(seriesA, amount);

        seriesAMintedAmount = seriesAMintedAmount.add(amount);
        require(seriesAMintedAmount <= seriesAMaxSupply, "minted amount exceeds max supply");
    }

    function l2Mint() public {
        L2Caller l2Caller = L2Caller(msg.sender);
        require(msg.sender == address(0x0000000000000000000000000000000000000000), "");
        require(l2Caller.l2Sender() == address(0x0000000000000000000000000000000000000000), "");
        uint256 newIndex = releaseReceipts.length;
        releaseReceipts[newIndex] = ReleaseReceipt({
            releaseType: ReleaseToL1,
            executed: false,
            recipient: address(0x0000000000000000000000000000000000000000),
            amount: 0
        });
        emit RequestFromL2();
    }

    function baseMint(uint256 receiptIndex) public {
        ReleaseReceipt storage receipt = releaseReceipts[receiptIndex];
        require(receipt.releaseType != ReleaseType.NoneType && !receipt.executed, "");
        _baseMint(receipt.recipient, receipt.amount);
        receipt.executed = true;
    }

    function _baseMint(address recipient, uint256 amount) internal {
        updateMintableAmount();
        require(amount <= _getBaseMintableAmount(), "amount exceeds max mintable amount");
        _mint(recipient, amount);
        baseMintedAmount = baseMintedAmount.add(amount);
        require(baseMintedAmount <= baseMaxSupply, "minted amount exceeds max supply");
    }

    function _mint(address recipient, uint256 amount) internal {
        require(amount > 0, "amount is zero");
        require(
            mcbToken.totalSupply().add(amount) <= mcbTotalSupply(),
            "mint amount exceeds total supply"
        );

        uint256 toDevAmount = amount.mul(devCommissionRate()).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(recipient, toRecipientAmount);
        mcbToken.mint(devAccount, toDevAmount);

        emit MintMCB(recipient, toRecipientAmount, devAccount, toDevAmount);
    }

    function updateMintableAmount() public {
        _updateExtraMintableAmount();
        updateSeriesAMintableAmount();
    }

    function updateSeriesAMintableAmount() public {
        if (_getBlockNumber() <= seriesALastUpdateBlock || extraMintableAmount == 0) {
            return;
        }
        uint256 remainSupply = seriesAMaxSupply.sub(seriesAMintedAmount).sub(seriesAMintableAmount);
        if (remainSupply == 0) {
            return;
        }
        uint256 elapsedBlock = _getBlockNumber().sub(seriesALastUpdateBlock);
        uint256 mintableAmount =
            elapsedBlock.mul(seriesAMaxReleaseRate).min(extraMintableAmount).min(remainSupply);
        // **TO SERIES A**: extra
        seriesAMintableAmount = seriesAMintableAmount.add(mintableAmount);
        extraMintableAmount = extraMintableAmount.sub(mintableAmount);
        seriesALastUpdateBlock = _getBlockNumber();
    }

    function _updateExtraMintableAmount() internal {
        if (_getBlockNumber() <= _getLastValueCapturedBlock()) {
            return;
        }
        uint256 capturedValue = valueCapture.totalCapturedUSD();
        uint256 incrementalCapturedValue = capturedValue.sub(totalCapturedValue);
        {
            uint256 elapsedBlock = _getBlockNumber().sub(_getLastValueCapturedBlock());
            uint256 baseMintableAmount = elapsedBlock.mul(baseMinReleaseRate);
            if (incrementalCapturedValue > baseMintableAmount) {
                extraMintableAmount = incrementalCapturedValue.sub(baseMintableAmount);
            }
            lastValueCapturedBlock = _getBlockNumber();
        }
        totalCapturedValue = capturedValue;
    }

    function _getLastValueCapturedBlock() internal view returns (uint256) {
        return lastValueCapturedBlock < genesisBlock() ? genesisBlock() : lastValueCapturedBlock;
    }

    function _getSeriesALastUpdateBlock() internal view returns (uint256) {
        return seriesALastUpdateBlock < genesisBlock() ? genesisBlock() : seriesALastUpdateBlock;
    }

    function _getBaseMintableAmount() internal view returns (uint256) {
        uint256 cumulativeMintableAmount =
            baseMinReleaseRate.mul(_getBlockNumber().sub(genesisBlock())).add(extraMintableAmount);
        return
            cumulativeMintableAmount > baseMintedAmount
                ? cumulativeMintableAmount.sub(baseMintedAmount)
                : 0;
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }
}

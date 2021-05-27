// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/IL2ArbNetwork.sol";
import "../interfaces/IDataExchange.sol";
import "../interfaces/IValueCapture.sol";
import "../interfaces/IMCB.sol";
import "../Environment.sol";

contract MockMinter is ReentrancyGuard, Environment {
    using Address for address;
    using Math for uint256;
    using SafeMath for uint256;

    bytes32 public constant MCB_TOTAL_SUPPLY_KEY = keccak256("MCB_TOTAL_SUPPLY_KEY");
    bytes32 public constant TOTAL_CAPTURED_USD_KEY = keccak256("TOTAL_CAPTURED_USD_KEY");

    enum ReleaseType { None, ToL1, ToL2 }

    struct MintRequest {
        ReleaseType releaseType;
        bool executed;
        address recipient;
        uint256 amount;
    }

    address public devAccount;
    address public l2SeriesAVesting;

    uint256 public totalCapturedValue;
    uint256 public extraMintableAmount;
    uint256 public lastValueCapturedBlock;

    uint256 public baseMaxSupply;
    uint256 public baseMintedAmount;
    uint256 public baseMintableAmount;
    uint256 public baseMinReleaseRate;
    uint256 public baseLastUpdateBlock;

    uint256 public seriesAMaxSupply;
    uint256 public seriesAMintableAmount;
    uint256 public seriesAMintedAmount;
    uint256 public seriesAMaxReleaseRate;
    uint256 public seriesALastUpdateBlock;

    address public mintInitiator;

    IMCB public mcbToken;
    IDataExchange public dataExchange;
    MintRequest[] public mintRequests;

    event MintToL1(
        address indexed recipient,
        uint256 recipientReceivedAmount,
        address indexed devAccount,
        uint256 devReceivedAmount
    );
    event MintToL2(
        address indexed recipient,
        uint256 recipientReceivedAmount,
        address indexed devAccount,
        uint256 devReceivedAmount
    );

    event SetDevAccount(address indexed devOld, address indexed devNew);
    event ReceiveMintRequest(
        uint256 index,
        ReleaseType releaseType,
        address indexed recipient,
        uint256 amount
    );
    event ExecuteMintRequest(
        uint256 index,
        ReleaseType releaseType,
        address indexed recipient,
        uint256 amount
    );

    constructor(
        address mintInitiator_,
        address mcbToken_,
        address dataExchange_,
        address l2SeriesAVesting_,
        address devAccount_,
        uint256 baseMaxSupply_,
        uint256 seriesAMaxSupply_,
        uint256 baseMinReleaseRate_,
        uint256 seriesAMaxReleaseRate_
    ) {
        require(mcbToken_.isContract(), "token must be contract");
        require(dataExchange_.isContract(), "data exchange must be contract");

        mintInitiator = mintInitiator_;
        mcbToken = IMCB(mcbToken_);
        dataExchange = IDataExchange(dataExchange_);
        l2SeriesAVesting = l2SeriesAVesting_;
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

    /**
     * @notice The start block to release MCB.
     */
    function genesisBlock() public pure virtual returns (uint256) {
        return 0;
    }

    /**
     * @notice The max MCB supply including the released part and the part to be released.
     */
    function mcbTotalSupply() public pure virtual returns (uint256) {
        return 10000000 * 1e18; // 10,000,000
    }

    /**
     * @notice The dev team will share 25% of the amount to be minted.
     */
    function devCommissionRate() public pure virtual returns (uint256) {
        return 25 * 1e16; // 25%
    }

    /**
     * @notice  Set the dev account who is the beneficiary of shares from minted MCB token.
     */
    function setDevAccount(address devAccount_) external {
        require(devAccount_ != address(0x0), "zero address is not allowed");
        require(msg.sender == devAccount, "caller must be dev account");
        require(devAccount_ != devAccount, "already dev account");
        emit SetDevAccount(devAccount, devAccount_);
        devAccount = devAccount_;
    }

    /**
     * @notice  Update mintable amount. There are two types of minting, with different destination: base and series-A.
     *          The base mintable amount is composed of a constant releasing rate and the fee catpure from liqudity pool;
     *          The series-A part is mainly from the captured part of base mintable amount.
     *          This method updates both the base part and the series-A part. To see the rule, check ... for details.
     */
    function updateMintableAmount() public {
        _updateBaseMintableAmount();
        _updateExtraMintableAmount();
        _updateSeriesAMintableAmount();
    }

    /**
     * @notice  Update the mintable amount for series-A separately.
     */
    function updateSeriesAMintableAmount() public {
        _updateExtraMintableAmount();
        _updateSeriesAMintableAmount();
    }

    /**
     * @notice  Get the mintable amount for series-A.
     */
    function getSeriesAMintableAmount() external view returns (uint256) {
        uint256 remainingAmount =
            seriesAMaxSupply > seriesAMintedAmount ? seriesAMaxSupply.sub(seriesAMintedAmount) : 0;
        return seriesAMintableAmount.min(remainingAmount);
    }

    /**
     * @notice  Get the mintable amount for base.
     */
    function getBaseMintableAmount() public view returns (uint256) {
        uint256 remainingAmount =
            baseMaxSupply > baseMintedAmount ? baseMaxSupply.sub(baseMintedAmount) : 0;
        return baseMintableAmount.add(extraMintableAmount).min(remainingAmount);
    }

    /**
     * @notice  Receive minting request sent by `MintInitiator`.
     *          The request will be stored into an array, and later be executed.
     */
    function receiveBaseMintRequestFromL2(
        uint8 releaseType,
        address recipient,
        uint256 amount
    ) external nonReentrant {
        require(_getL2Sender(msg.sender) == mintInitiator, "sender is not the initiator");
        uint256 index = mintRequests.length;
        mintRequests.push(
            MintRequest({
                releaseType: ReleaseType(releaseType),
                executed: false,
                recipient: recipient,
                amount: amount
            })
        );
        emit ReceiveMintRequest(index, ReleaseType(releaseType), recipient, amount);
    }

    /**
     * @notice   Execute a minting request, mint token to different recipient according to the `mintType`.
     */
    function executeBaseMintRequest(
        uint256 index,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external nonReentrant {
        MintRequest storage request = mintRequests[index];
        require(request.releaseType != ReleaseType.None, "request has been executed");
        require(!request.executed, "request has been executed");
        require(request.amount <= getBaseMintableAmount(), "amount exceeds max mintable amount");
        require(
            baseMintedAmount.add(request.amount) <= baseMaxSupply,
            "minted amount exceeds max base supply"
        );

        if (request.releaseType == ReleaseType.ToL1) {
            _mintToL1(request.recipient, request.amount);
        } else if (request.releaseType == ReleaseType.ToL1) {
            _mintToL2(
                request.recipient,
                request.amount,
                bridge,
                maxSubmissionCost,
                maxGas,
                gasPriceBid
            );
        } else {
            revert("unrecognized release type");
        }
        if (request.amount <= baseMintableAmount) {
            baseMintableAmount = baseMintableAmount.sub(request.amount);
        } else {
            extraMintableAmount = extraMintableAmount.sub(request.amount.sub(baseMintableAmount));
            baseMintableAmount = 0;
        }
        baseMintedAmount = baseMintedAmount.add(request.amount);
        request.executed = true;
        _syncTotalSupply(bridge, maxGas, gasPriceBid);

        emit ExecuteMintRequest(index, request.releaseType, request.recipient, request.amount);
    }

    /**
     * @notice  Mint MCB to series-A recipient. Can be called by any one.
     */
    function seriesAMint(
        uint256 amount,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external nonReentrant {
        require(amount <= seriesAMintableAmount, "amount exceeds max mintable amount");
        require(
            seriesAMintedAmount.add(amount) <= seriesAMaxSupply,
            "minted amount exceeds max series-a supply"
        );
        _mintToL2(l2SeriesAVesting, amount, bridge, maxSubmissionCost, maxGas, gasPriceBid);
        seriesAMintableAmount = seriesAMintableAmount.sub(amount);
        seriesAMintedAmount = seriesAMintedAmount.add(amount);
    }

    function _mintToL1(address recipient, uint256 amount) internal returns (uint256, uint256) {
        require(recipient != address(0), "recipient is the zero address");
        require(amount > 0, "amount is zero");

        uint256 toDevAmount = amount.mul(devCommissionRate()).div(1e18);
        uint256 toRecipientAmount = amount.sub(toDevAmount);
        require(
            mcbToken.totalSupply().add(amount) < mcbTotalSupply(),
            "minted amount exceeds max total supply"
        );
        mcbToken.mint(recipient, toRecipientAmount);
        mcbToken.mint(devAccount, toDevAmount);

        emit MintToL1(recipient, toRecipientAmount, devAccount, toDevAmount);
        return (toDevAmount, toRecipientAmount);
    }

    function _mintToL2(
        address recipient,
        uint256 amount,
        address,
        uint256,
        uint256,
        uint256
    ) internal returns (uint256, uint256) {
        (uint256 toDevAmount, uint256 toRecipientAmount) = _mintToL1(recipient, amount);
        emit MintToL2(recipient, toRecipientAmount, devAccount, toDevAmount);
        return (toDevAmount, toRecipientAmount);
    }

    function syncTotalSupply(
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external {
        require(_syncTotalSupply(inbox, maxGas, gasPriceBid), "fail to sync total supply");
    }

    function _syncTotalSupply(
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) internal returns (bool) {
        // require(_isValidInbox(inbox), "inbox is invalid");
        return
            dataExchange.tryFeedDataFromL1(
                MCB_TOTAL_SUPPLY_KEY,
                abi.encode(mcbToken.totalSupply()),
                inbox,
                maxGas,
                gasPriceBid
            );
    }

    function _isValidInbox(address inbox) internal view returns (bool) {
        return true;
    }

    function _getL2Sender(address) internal view returns (address) {
        return msg.sender;
    }

    function _updateBaseMintableAmount() internal {
        uint256 currentBlock = _getBlockNumber();
        // if already updated
        if (baseLastUpdateBlock >= currentBlock) {
            return;
        }
        uint256 elapsedBlock = currentBlock.sub(baseLastUpdateBlock);
        baseMintableAmount = baseMintableAmount.add(elapsedBlock.mul(baseMinReleaseRate));
        baseLastUpdateBlock = currentBlock;
    }

    /**
     * @dev Note that this method will only sync mintable amount to captured block from data exchange.
     *      **NOT** current block.
     */
    function _updateExtraMintableAmount() internal {
        (uint256 capturedValue, uint256 capturedBlock) = _getTotalCapturedUSD();
        if (lastValueCapturedBlock >= capturedBlock) {
            return;
        }
        uint256 elapsedBlockUntilCaptured = capturedBlock.sub(_getLastValueCapturedBlock());
        uint256 minimalMintableAmount = elapsedBlockUntilCaptured.mul(baseMinReleaseRate);
        // base extra mintable amount
        uint256 incrementalCapturedValue = capturedValue.sub(totalCapturedValue);
        if (incrementalCapturedValue > minimalMintableAmount) {
            extraMintableAmount = extraMintableAmount.add(
                incrementalCapturedValue.sub(minimalMintableAmount)
            );
        }
        lastValueCapturedBlock = capturedBlock;
        totalCapturedValue = capturedValue;
    }

    function _updateSeriesAMintableAmount() public {
        if (_getBlockNumber() <= _getSeriesALastUpdateBlock() || extraMintableAmount == 0) {
            return;
        }
        uint256 remainSupply = seriesAMaxSupply.sub(seriesAMintedAmount).sub(seriesAMintableAmount);
        if (remainSupply == 0) {
            return;
        }
        uint256 elapsedBlock = _getBlockNumber().sub(_getSeriesALastUpdateBlock());
        uint256 mintableAmount =
            elapsedBlock.mul(seriesAMaxReleaseRate).min(extraMintableAmount).min(remainSupply);
        // substract from extra, add to series-A
        seriesAMintableAmount = seriesAMintableAmount.add(mintableAmount);
        extraMintableAmount = extraMintableAmount.sub(mintableAmount);
        seriesALastUpdateBlock = _getBlockNumber();
    }

    function _getTotalCapturedUSD() internal view returns (uint256, uint256) {
        (bytes memory data, bool exist) = dataExchange.getData(TOTAL_CAPTURED_USD_KEY);
        if (!exist) {
            return (0, 0);
        }
        require(data.length >= 64, "malformed raw data for captured value");
        return abi.decode(data, (uint256, uint256));
    }

    function _getLastValueCapturedBlock() internal view returns (uint256) {
        return lastValueCapturedBlock < genesisBlock() ? genesisBlock() : lastValueCapturedBlock;
    }

    function _getSeriesALastUpdateBlock() internal view returns (uint256) {
        return seriesALastUpdateBlock < genesisBlock() ? genesisBlock() : seriesALastUpdateBlock;
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    bytes32[50] private __gap;
}

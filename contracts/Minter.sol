// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IL2ArbNetwork.sol";
import "./interfaces/IDataExchange.sol";
import "./interfaces/IValueCapture.sol";
import "./interfaces/IMCB.sol";

contract Minter {
    using Address for address;
    using SafeMath for uint256;
    using Math for uint256;

    address public constant MINT_INITIATOR_ADDRESS = 0xC0250Ed5Da98696386F13bE7DE31c1B54a854098;
    address public constant ROLLUP_ADDRESS = 0xC0250Ed5Da98696386F13bE7DE31c1B54a854098;
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
    IDataExchange public dataExchange;
    MintRequest[] public mintRequests;

    event MintToL1(address indexed recipient, uint256 amount);
    event MintToL2(address indexed recipient, uint256 amount);
    event MintMCB(
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
        _updateExtraMintableAmount();
        updateSeriesAMintableAmount();
    }

    /**
     * @notice  Update the mintable amount for series-A separately.
     */
    function updateSeriesAMintableAmount() public {
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
        // **TO SERIES A**: extra
        seriesAMintableAmount = seriesAMintableAmount.add(mintableAmount);
        extraMintableAmount = extraMintableAmount.sub(mintableAmount);
        seriesALastUpdateBlock = _getBlockNumber();
    }

    /**
     * @notice  Get the mintable amount for series-A.
     */
    function getSeriesAMintableAmount() external returns (uint256) {
        updateMintableAmount();
        return seriesAMintableAmount.min(seriesAMaxSupply);
    }

    /**
     * @notice  Get the mintable amount for base.
     */
    function getBaseMintableAmount() external returns (uint256) {
        updateMintableAmount();
        return _getBaseMintableAmount().min(baseMaxSupply);
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
    ) external {
        updateMintableAmount();
        require(amount <= seriesAMintableAmount, "amount exceeds max mintable amount");
        _mintToL2(l2SeriesAVesting, amount, bridge, maxSubmissionCost, maxGas, gasPriceBid);
        seriesAMintableAmount = seriesAMintableAmount.sub(amount);
        seriesAMintedAmount = seriesAMintedAmount.add(amount);
        require(seriesAMintedAmount <= seriesAMaxSupply, "minted amount exceeds max supply");
    }

    /**
     * @notice  Receive minting request sent by `MintInitiator`.
     *          The request will be stored into an array, and later be executed.
     */
    function receiveMintRequestFromL2(
        uint8 releaseType,
        address recipient,
        uint256 amount
    ) external {
        require(_getL2Sender(msg.sender) == MINT_INITIATOR_ADDRESS, "sender is not the initiator");
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
    function executeMintRequest(
        uint256 index,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external {
        MintRequest storage request = mintRequests[index];
        require(request.releaseType != ReleaseType.None, "request has been executed");
        require(!request.executed, "request has been executed");
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
        request.executed = true;
        emit ExecuteMintRequest(index, request.releaseType, request.recipient, request.amount);
    }

    function _mintToL1(address recipient, uint256 amount) internal {
        updateMintableAmount();
        require(amount <= _getBaseMintableAmount(), "amount exceeds max mintable amount");

        _mint(recipient, amount);
        baseMintedAmount = baseMintedAmount.add(amount);
        require(baseMintedAmount <= baseMaxSupply, "minted amount exceeds max supply");

        emit MintToL1(recipient, amount);
    }

    /**
     * @dev Mint MCB to self, then call bridge method to push token to L2.
     */
    function _mintToL2(
        address recipient,
        uint256 amount,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) internal {
        IL2ERC20Bridge erc20Bridge = IL2ERC20Bridge(bridge);
        require(_isValidInbox(erc20Bridge.inbox()), "inbox is invalid");
        updateMintableAmount();
        require(amount <= _getBaseMintableAmount(), "amount exceeds max mintable amount");
        _mint(address(this), amount);
        mcbToken.approve(bridge, amount);
        erc20Bridge.depositAsERC20(
            address(mcbToken),
            recipient,
            amount,
            maxSubmissionCost,
            maxGas,
            gasPriceBid,
            ""
        );
        baseMintedAmount = baseMintedAmount.add(amount);
        require(baseMintedAmount <= baseMaxSupply, "minted amount exceeds max supply");

        emit MintToL2(recipient, amount);
    }

    function _isValidInbox(address inbox) internal view returns (bool) {
        IBridge trustedBridge = IBridge(IRollup(ROLLUP_ADDRESS).bridge());
        return trustedBridge.allowedInboxes(inbox);
    }

    function _getL2Sender(address bridge) internal view returns (address) {
        address trustedBridge = IRollup(ROLLUP_ADDRESS).bridge();
        require(trustedBridge == bridge, "not a valid l2 outbox");
        IOutbox outbox = IOutbox(IBridge(trustedBridge).activeOutbox());
        return outbox.l2ToL1Sender();
    }

    function _mint(address recipient, uint256 amount) internal {
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

        emit MintMCB(recipient, toRecipientAmount, devAccount, toDevAmount);
    }

    function _updateExtraMintableAmount() internal {
        (uint256 capturedValue, uint256 capturedTimestamp) = _getTotalCapturedUSD();
        if (lastValueCapturedBlock >= capturedTimestamp) {
            return;
        }
        uint256 incrementalCapturedValue = capturedValue.sub(totalCapturedValue);
        uint256 elapsedBlock = capturedTimestamp.sub(_getLastValueCapturedBlock());
        uint256 baseMintableAmount = elapsedBlock.mul(baseMinReleaseRate);
        if (incrementalCapturedValue > baseMintableAmount) {
            extraMintableAmount = incrementalCapturedValue.sub(baseMintableAmount);
        }
        lastValueCapturedBlock = capturedTimestamp;
        totalCapturedValue = capturedValue;
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

    bytes32[50] private __gap;
}

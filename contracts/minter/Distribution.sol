// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { Config } from "./Config.sol";
import { Context } from "./Context.sol";

import "hardhat/console.sol";

/**
 * @dev Define how the MCB will be distributed among DAO controlled part and vesting part.
 */
abstract contract Distribution is Initializable, Context, Config {
    using SafeMathUpgradeable for uint256;
    using MathUpgradeable for uint256;

    struct Round {
        address recipient;
        // won't change
        uint128 maxSupply;
        uint128 rateLimitPerBlock;
        // always updated together, DO NOT change the order of below 2 fields
        uint128 mintableAmount;
        uint128 lastUpdateBlock;
        // changed during mint
        uint128 mintedAmount;
    }

    uint256 public extraMintableAmount;
    uint256 public lastCapturedValue;
    uint256 public lastCapturedBlock;

    Round public baseMintState; // all other funds goes to here
    Round[] public roundMintStates; // funding roundMintStates with priority from 0 -> ∞

    event NewRound(uint256 index, uint128 maxSupply, uint128 rateLimitPerBlock, uint128 startBlock);
    event BaseRelease(uint256 amount);
    event RoundRelease(uint256 index, uint256 amount);
    event UpdateExtraMintableAmount(
        uint256 lastCapturedBlock,
        uint256 capturedBlock,
        uint256 capturedValue,
        uint256 extraMintableAmount
    );
    event UpdateRoundMintableAmount(
        uint256 lastUpdateBlock,
        uint256 currentBlock,
        uint256 seriesAMintableAmount,
        uint256 extraMintableAmount
    );
    event UpdateBaseMintableAmount(
        uint256 lastUpdateBlock,
        uint256 currentBlock,
        uint256 baseMintableAmount
    );

    function __Distribution_init(uint128 baseInitialSupply_, uint128 baseMinReleaseRate_)
        internal
        initializer
    {
        require(baseMinReleaseRate_ > 0, "baseMinReleaseRate is zero");
        require(baseInitialSupply_ <= MCB_MAX_SUPPLY, "invalid supplies");

        baseMintState.maxSupply = _safe128(MCB_MAX_SUPPLY.sub(uint256(baseInitialSupply_)));
        baseMintState.rateLimitPerBlock = baseMinReleaseRate_;
    }

    /**
     * @dev Remaining supply of base part, which can be splited into new round, or be minted by DAO.
     */
    function _remainingSupply() internal view returns (uint256) {
        return
            uint256(baseMintState.maxSupply).sub(baseMintState.mintedAmount).sub(
                baseMintState.mintableAmount
            );
    }

    /**
     * @dev Get the mintable amount for base part. limit to the maxSupply.
     *      When access from external, call update before try to get the real amount.
     */
    function _baseMintableAmount() internal view returns (uint256) {
        uint256 remainingAmount = baseMintState.maxSupply > baseMintState.mintedAmount
            ? uint256(baseMintState.maxSupply).sub(baseMintState.mintedAmount)
            : 0;
        return extraMintableAmount.add(baseMintState.mintableAmount).min(remainingAmount);
    }

    /**
     * @notice  Get the mintable amount for the round specified by index.
     *          roundMintable = min(min(maxReleaseRate * elapsedBlock, extraMintable), maxSupply)
     */
    function _roundMintableAmount(uint256 index) internal view returns (uint256) {
        require(index < roundMintStates.length, "round not exists");
        Round storage round = roundMintStates[index];
        uint256 remainingAmount = round.maxSupply > round.mintedAmount
            ? uint256(round.maxSupply).sub(round.mintedAmount)
            : 0;
        return uint256(round.mintableAmount).min(remainingAmount);
    }

    /**
     * @dev Create a new round.
     */
    function _newRound(
        address recipient,
        uint128 maxSupply,
        uint128 rateLimitPerBlock,
        uint128 startBlock
    ) internal {
        require(_remainingSupply() >= maxSupply, "insufficient supply for new round");
        require(rateLimitPerBlock > 0, "rateLimitPerBlock is zero");
        require(startBlock > _blockNumber(), "startBlock should be later than current");

        uint256 index = roundMintStates.length;
        Round memory newRound = Round({
            recipient: recipient,
            maxSupply: maxSupply,
            rateLimitPerBlock: rateLimitPerBlock,
            mintableAmount: 0,
            lastUpdateBlock: startBlock,
            mintedAmount: 0
        });
        roundMintStates.push(newRound);
        baseMintState.maxSupply = _safe128(uint256(baseMintState.maxSupply).sub(maxSupply));
        emit NewRound(index, maxSupply, rateLimitPerBlock, startBlock);
    }

    /**
     * @dev Update extra mintable amount according to value captured by ValueCapture contract.
     */
    function _updateExtraMintableAmount(uint256 capturedValue, uint256 blockNumber)
        internal
        returns (bool)
    {
        uint256 elapsedBlock = _getElapsedBlock(lastCapturedBlock, blockNumber);
        if (elapsedBlock == 0) {
            return false;
        }

        uint256 minMintableAmount = elapsedBlock.mul(baseMintState.rateLimitPerBlock);
        uint256 incrementalCapturedValue = capturedValue.sub(
            lastCapturedValue,
            "captured value can not decrease"
        );
        bool hasCapturedValue = incrementalCapturedValue > minMintableAmount;
        if (hasCapturedValue) {
            extraMintableAmount = extraMintableAmount.add(
                incrementalCapturedValue.sub(minMintableAmount)
            );
        }
        lastCapturedValue = capturedValue;
        lastCapturedBlock = blockNumber;
        emit UpdateExtraMintableAmount(
            lastCapturedBlock,
            blockNumber,
            capturedValue,
            extraMintableAmount
        );
        return hasCapturedValue;
    }

    function _updateMintableAmount() internal {
        _updateRoundMintableAmount();
        _updateBaseMintableAmount();
    }

    /**
     * @dev Update and set the mintable amount for base.
     *      baseMintable = min(minReleaseRate * elapsedBlock + extraMintable, maxSupply)
     */
    function _updateBaseMintableAmount() internal {
        uint256 currentBlock = _blockNumber();
        uint256 elapsedBlock = _getElapsedBlock(baseMintState.lastUpdateBlock, currentBlock);
        if (elapsedBlock == 0) {
            return;
        }
        uint256 mintableAmount = elapsedBlock.mul(baseMintState.rateLimitPerBlock);
        // update amount && block
        baseMintState.mintableAmount = _safe128(mintableAmount.add(baseMintState.mintableAmount));
        emit UpdateBaseMintableAmount(
            baseMintState.lastUpdateBlock,
            currentBlock,
            baseMintState.mintableAmount
        );
        baseMintState.lastUpdateBlock = _safe128(currentBlock);
    }

    /**
     * @dev Update the amounts of all rounds.
     */
    function _updateRoundMintableAmount() internal {
        uint256 count = roundMintStates.length;
        for (uint256 i = 0; i < count; i++) {
            _updateRoundMintableAmount(i);
        }
    }

    /**
     * @dev Update and set the mintable amount for one round.
     *      This method should not be called separately since the priority consuming extraMintableAmount should follow
     *      the order of index ,where the index 0 is the highest priority round.
     */
    function _updateRoundMintableAmount(uint256 index) internal returns (uint256 mintableAmount) {
        require(index < roundMintStates.length, "round not exists");
        Round storage round = roundMintStates[index];
        mintableAmount = round.mintableAmount;
        if (extraMintableAmount == 0) {
            return mintableAmount;
        }
        uint256 elapsedBlock = _getElapsedBlock(round.lastUpdateBlock, lastCapturedBlock);
        if (elapsedBlock == 0) {
            return mintableAmount;
        }
        uint256 remainSupply = uint256(round.maxSupply).sub(round.mintedAmount).sub(
            round.mintableAmount
        );
        if (remainSupply == 0) {
            return mintableAmount;
        }
        mintableAmount = elapsedBlock.mul(round.rateLimitPerBlock).min(extraMintableAmount).min(
            remainSupply
        );
        // minus from extra, add to series-X round
        extraMintableAmount = extraMintableAmount.sub(mintableAmount);
        // update amount && block
        round.mintableAmount = _safe128(mintableAmount.add(round.mintableAmount));
        emit UpdateRoundMintableAmount(
            round.lastUpdateBlock,
            lastCapturedBlock,
            round.mintableAmount,
            extraMintableAmount
        );
        round.lastUpdateBlock = _safe128(lastCapturedBlock);
        return mintableAmount;
    }

    /**
     * @dev Release mintable part from base.
     */
    function _releaseFromBase(uint256 amount) internal {
        uint256 mintableAmount = _baseMintableAmount();
        require(amount <= mintableAmount, "amount exceeds max mintable amount");

        if (amount > baseMintState.mintableAmount) {
            uint256 amountFromExtra = amount.sub(baseMintState.mintableAmount);
            baseMintState.mintableAmount = 0;
            extraMintableAmount = extraMintableAmount.sub(amountFromExtra);
        } else {
            baseMintState.mintableAmount = _safe128(
                uint256(baseMintState.mintableAmount).sub(amount)
            );
        }
        baseMintState.mintedAmount = _safe128(uint256(baseMintState.mintedAmount).add(amount));
        emit BaseRelease(amount);
    }

    /**
     * @dev Release mintable part from one round.
     */
    function _releaseFromRound(uint256 index, uint256 amount) internal {
        require(index < roundMintStates.length, "round not exists");
        uint256 mintableAmount = _roundMintableAmount(index);
        require(amount <= mintableAmount, "amount exceeds max mintable amount");

        Round storage round = roundMintStates[index];
        round.mintableAmount = _safe128(uint256(round.mintableAmount).sub(amount));
        round.mintedAmount = _safe128(uint256(round.mintedAmount).add(amount));

        emit RoundRelease(index, amount);
    }

    function _roundRecipient(uint256 index) internal view returns (address) {
        require(index < roundMintStates.length, "round not exists");
        return roundMintStates[index].recipient;
    }

    function _getElapsedBlock(uint256 begin, uint256 end) internal view returns (uint256) {
        begin = _safeBlockNumber(begin);
        if (begin >= end) {
            return 0;
        }
        return end.sub(begin);
    }

    function _safe128(uint256 n) internal pure returns (uint128) {
        require(n < type(uint128).max, "exceeds uint128");
        return uint128(n);
    }

    bytes32[50] private __gap;
}

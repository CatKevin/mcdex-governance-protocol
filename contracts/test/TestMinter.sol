// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "../Minter.sol";

contract TestMinter is Minter {
    using Math for uint256;
    using SafeMath for uint256;
    uint256 internal _mockBlockNumber;

    constructor(
        address mcbToken_,
        address valueCapture_,
        address seriesA_,
        address devAccount_,
        uint256 baseMaxSupply_,
        uint256 seriesAMaxSupply_,
        uint256 baseMinReleaseRate_,
        uint256 seriesAMaxReleaseRate_
    )
        Minter(
            mcbToken_,
            valueCapture_,
            seriesA_,
            devAccount_,
            baseMaxSupply_,
            seriesAMaxSupply_,
            baseMinReleaseRate_,
            seriesAMaxReleaseRate_
        )
    {}

    function setBlockNumber(uint256 blockNumber) public {
        _mockBlockNumber = blockNumber;
    }

    function _getBlockNumber() internal view virtual override returns (uint256) {
        return _mockBlockNumber;
    }

    function testSeriesAMint(address to, uint256 amount) external {
        require(amount <= seriesAMintableAmount, "amount exceeds max mintable amount");
        require(
            seriesAMintedAmount.add(amount) <= seriesAMaxSupply,
            "minted amount exceeds max supply"
        );
        seriesAMintableAmount = seriesAMintableAmount.sub(amount);
        seriesAMintedAmount = seriesAMintedAmount.add(amount);
        _mintToL1(to, amount);
    }

    function testBaseMint(address to, uint256 amount) external {
        require(amount <= getBaseMintableAmount(), "amount exceeds max mintable amount");
        baseMintedAmount = baseMintedAmount.add(amount);
        if (amount <= baseMintableAmount) {
            baseMintableAmount = baseMintableAmount.sub(amount);
        } else {
            extraMintableAmount = extraMintableAmount.sub(amount.sub(baseMintableAmount));
            baseMintableAmount = 0;
        }
        _mintToL1(to, amount);
    }

    function updateAndGetSeriesAMintableAmount() external returns (uint256) {
        updateMintableAmount();
        uint256 remainingAmount =
            seriesAMaxSupply > seriesAMintedAmount ? seriesAMaxSupply.sub(seriesAMintedAmount) : 0;
        return seriesAMintableAmount.min(remainingAmount);
    }

    /**
     * @notice  Get the mintable amount for base.
     */
    function updateAndGetBaseMintableAmount() external returns (uint256) {
        updateMintableAmount();
        uint256 remainingAmount =
            baseMaxSupply > baseMintedAmount ? baseMaxSupply.sub(baseMintedAmount) : 0;
        return baseMintableAmount.add(extraMintableAmount).min(remainingAmount);
    }
}

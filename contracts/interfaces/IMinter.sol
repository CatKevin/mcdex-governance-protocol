// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface IMinter {
    function devAccount() external view returns (address);

    function l2SeriesAVesting() external view returns (address);

    function mintInitiator() external view returns (address);

    function mcbToken() external view returns (address);

    function dataExchange() external view returns (address);

    function totalCapturedValue() external view returns (uint256);

    function extraMintableAmount() external view returns (uint256);

    function lastValueCapturedBlock() external view returns (uint256);

    function baseMaxSupply() external view returns (uint256);

    function baseMintedAmount() external view returns (uint256);

    function baseMintableAmount() external view returns (uint256);

    function baseMinReleaseRate() external view returns (uint256);

    function seriesAMaxSupply() external view returns (uint256);

    function seriesAMintableAmount() external view returns (uint256);

    function seriesAMintedAmount() external view returns (uint256);

    function seriesAMaxReleaseRate() external view returns (uint256);

    /**
     * @notice The start block to release MCB.
     */
    function genesisBlock() external pure returns (uint256);

    /**
     * @notice The max MCB supply including the released part and the part to be released.
     */
    function mcbTotalSupply() external pure returns (uint256);

    /**
     * @notice The dev team will share 25% of the amount to be minted.
     */
    function devCommissionRate() external pure returns (uint256);

    /**
     * @notice  Set the dev account who is the beneficiary of shares from minted MCB token.
     */
    function setDevAccount(address devAccount_) external;

    /**
     * @notice  Update mintable amount. There are two types of minting, with different destination: base and series-A.
     *          The base mintable amount is composed of a constant releasing rate and the fee catpure from liqudity pool;
     *          The series-A part is mainly from the captured part of base mintable amount.
     *          This method updates both the base part and the series-A part. To see the rule, check ... for details.
     */
    function updateMintableAmount() external;

    /**
     * @notice  Update the mintable amount for series-A separately.
     */
    function updateSeriesAMintableAmount() external;

    /**
     * @notice  Get the mintable amount for series-A.
     */
    function getSeriesAMintableAmount() external view returns (uint256);

    /**
     * @notice  Get the mintable amount for base.
     */
    function getBaseMintableAmount() external view returns (uint256);

    /**
     * @notice   Execute a minting request, mint token to different recipient according to the `mintType`.
     */
    function executeBaseMintRequest(
        uint256 index,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external;

    /**
     * @notice  Mint MCB to series-A recipient. Can be called by any one.
     */
    function seriesAMint(
        uint256 amount,
        address bridge,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external;
}

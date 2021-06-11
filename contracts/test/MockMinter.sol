// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/math/Math.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../Minter.sol";

contract MockMinter is Minter {
    constructor(
        address mintInitiator_,
        address mcbToken_,
        address dataExchange_,
        address l2SeriesAVesting_,
        address devAccount_,
        uint256 baseMaxSupply_,
        uint256 seriesAMaxSupply_,
        uint256 baseMinReleaseRate_,
        uint256 seriesAMaxReleaseRate_,
        uint256 baseIntialMintedAmount_
    )
        Minter(
            mintInitiator_,
            mcbToken_,
            dataExchange_,
            l2SeriesAVesting_,
            devAccount_,
            baseMaxSupply_,
            seriesAMaxSupply_,
            baseMinReleaseRate_,
            seriesAMaxReleaseRate_,
            baseIntialMintedAmount_
        )
    {}

    /**
     * @notice The start block to release MCB.
     */
    function genesisBlock() public view virtual override returns (uint256) {
        return 8743777;
    }

    function _mintToL2(
        address recipient,
        uint256 amount,
        address,
        uint256,
        uint256,
        uint256
    ) internal virtual override returns (uint256, uint256) {
        (uint256 toDevAmount, uint256 toRecipientAmount) = _mintToL1(recipient, amount);
        emit MintToL2(recipient, toRecipientAmount, devAccount, toDevAmount);
        return (toDevAmount, toRecipientAmount);
    }

    function _syncTotalSupply(
        address inbox,
        uint256 maxGas,
        uint256 gasPriceBid
    ) internal virtual override returns (bool) {
        return
            dataExchange.tryFeedDataFromL1(
                MCB_TOTAL_SUPPLY_KEY,
                abi.encode(mcbToken.totalSupply()),
                inbox,
                maxGas,
                gasPriceBid
            );
    }

    function _isValidInbox(address inbox) internal view virtual override returns (bool) {
        return true;
    }

    function _getL2Sender(address) internal view virtual override returns (address) {
        return msg.sender;
    }
}

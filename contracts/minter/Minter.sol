// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { IMCB } from "../interfaces/IMCB.sol";

import { Context } from "./Context.sol";
import { Config } from "./Config.sol";

abstract contract Minter is Initializable, Context, Config {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    IMCB public mcbToken;
    address public developer;

    event SetDeveloper(address indexed oldDeveloper, address indexed newDeveloper);
    event Mint(
        address indexed recipient,
        uint256 toRecipientAmount,
        address indexed developer,
        uint256 toDevAmount
    );

    function __Minter_init(address mcbToken_, address developer_) internal initializer {
        require(mcbToken_.isContract(), "token must be contract");
        require(developer_ != address(0), "dev account is zero address");

        mcbToken = IMCB(mcbToken_);
        _setDeveloper(developer_);
    }

    /**
     * @dev  Set the dev account who is the beneficiary of shares from minted MCB token.
     */
    function _setDeveloper(address newDeveloper) internal {
        require(newDeveloper != address(0x0), "newDeveloper is zero address");
        require(newDeveloper != developer, "newDeveloper is already the active developer");
        emit SetDeveloper(developer, newDeveloper);
        developer = newDeveloper;
    }

    function _mint(address recipient, uint256 amount)
        internal
        virtual
        returns (uint256 toDevAmount, uint256 toRecipientAmount)
    {
        require(recipient != address(0), "recipient is the zero address");
        require(amount > 0, "amount is zero");
        require(
            mcbToken.totalSupply().add(amount) < MCB_MAX_SUPPLY,
            "minted amount exceeds max total supply"
        );

        toDevAmount = amount.mul(DEVELOPER_COMMISSION_RATE).div(1e18);
        toRecipientAmount = amount.sub(toDevAmount);
        mcbToken.mint(recipient, toRecipientAmount);
        mcbToken.mint(developer, toDevAmount);

        emit Mint(recipient, toRecipientAmount, developer, toDevAmount);
    }

    bytes32[50] private __gap;
}

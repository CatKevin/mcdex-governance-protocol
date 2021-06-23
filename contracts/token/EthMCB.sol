// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/presets/ERC20PresetMinterPauserUpgradeable.sol";

import { IBridge, IInbox, IOutbox, ITokenGateway } from "../interfaces/IL2ArbNetwork.sol";

contract EthMCB is ERC20PresetMinterPauserUpgradeable {
    using AddressUpgradeable for address;

    address public inbox;
    address public gateway;
    address public l2Token;

    event RegisterTokenOnL2(
        address indexed gateway,
        address indexed l2Token,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    );
    event SetGateway(
        address indexed gateway,
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    );
    event EscrowMint(address indexed minter, uint256 amount);

    function initialize(
        string memory name_,
        string memory symbol_,
        address gateway_,
        address l2Token_
    ) external initializer {
        require(gateway_.isContract(), "gateway must be contract");
        require(l2Token_ != address(0), "l1Token must be non-zero address");

        __ERC20PresetMinterPauser_init(name_, symbol_);

        gateway = gateway_;
        l2Token = l2Token_;
    }

    /**
     * @notice Mint tokens to gateway, so that tokens minted from L2 will be able to withdraw from arb->eth.
     */
    function escrowMint(uint256 amount) external virtual {
        address msgSender = _l2Sender();
        require(msgSender == l2Token, "sender must be l2 token");
        _mint(gateway, amount);
        emit EscrowMint(msgSender, amount);
    }

    /**
     * @notice Register token address to paring with arb-token.
     */
    function registerTokenOnL2(
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable {
        bytes memory functionCallData = abi.encodeWithSignature(
            "registerTokenToL2(address,uint256,uint256,uint256)",
            l2Token,
            maxGas,
            gasPriceBid,
            maxSubmissionCost
        );
        gateway.functionCallWithValue(functionCallData, msg.value);
        emit RegisterTokenOnL2(gateway, l2Token, maxGas, gasPriceBid, maxSubmissionCost);
    }

    /**
     * @notice Register token to gateway.
     */
    function setGateway(
        uint256 maxSubmissionCost,
        uint256 maxGas,
        uint256 gasPriceBid
    ) external payable {
        bytes memory functionCallData = abi.encodeWithSignature(
            "setGateway(address,uint256,uint256,uint256)",
            gateway,
            maxGas,
            gasPriceBid,
            maxSubmissionCost
        );
        ITokenGateway(gateway).router().functionCallWithValue(functionCallData, msg.value);
        emit SetGateway(gateway, maxGas, gasPriceBid, maxSubmissionCost);
    }

    function _l2Sender() internal view virtual returns (address) {
        IBridge bridge = IInbox(inbox).bridge();
        require(address(bridge) != address(0), "bridge is zero address");
        IOutbox outbox = IOutbox(bridge.activeOutbox());
        require(address(outbox) != address(0), "outbox is zero address");
        return outbox.l2ToL1Sender();
    }

    uint256[50] private __gap;
}
